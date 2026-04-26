#include "ApiClient.h"
#include "AppSettings.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QHttpPart>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSslError>
#include <QUrl>
#include <QUrlQuery>

using namespace std::chrono_literals;

ApiClient::ApiClient(AppSettings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_nam(new QNetworkAccessManager(this))
{
    // L-01: loguj wszystkie błędy SSL (cert expired/self-signed/MITM hints).
    // Domyślnie QNAM cicho akceptuje zaufane certy i fail-closuje przy nieznanych
    // — to handler ŁAPIE problem zanim Qt go odrzuci, dając diagnostykę.
    // Nie wywołujemy ignoreSslErrors() — chcemy żeby fail-closed default Qt zostało.
    connect(m_nam, &QNetworkAccessManager::sslErrors, this,
            [](QNetworkReply *reply, const QList<QSslError> &errors) {
                for (const QSslError &err : errors) {
                    qWarning() << "[ApiClient] SSL error:" << err.errorString()
                               << "url:" << reply->url().toString();
                }
            });
}

QNetworkRequest ApiClient::prepareRequest(const QString &path,
                                          std::chrono::milliseconds timeout,
                                          bool withAuth) const
{
    QNetworkRequest req(QUrl(m_settings->apiUrl() + path));
    req.setTransferTimeout(timeout);
    if (withAuth && !m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }
    return req;
}

QString ApiClient::validatePhotoPath(const QString &photoPath)
{
    if (photoPath.isEmpty())
        return QStringLiteral("Brak ścieżki do zdjęcia");

    QFileInfo info(photoPath);
    const QString canonical = info.canonicalFilePath();
    if (canonical.isEmpty())  // canonicalFilePath = "" gdy plik nie istnieje
        return QStringLiteral("Plik nie istnieje: ") + photoPath;
    if (!info.isReadable())
        return QStringLiteral("Brak praw do odczytu: ") + canonical;
    if (info.isSymLink())
        return QStringLiteral("Odmowa: symlink (defense-in-depth)");

    const QString suffix = info.suffix().toLower();
    static const QStringList allowed = {QStringLiteral("jpg"), QStringLiteral("jpeg"),
                                        QStringLiteral("png"), QStringLiteral("heic"),
                                        QStringLiteral("heif")};
    if (!allowed.contains(suffix))
        return QStringLiteral("Niedozwolone rozszerzenie: ") + suffix;

    // Magic bytes check — pierwszy ~8 bajtów wystarcza
    QFile probe(canonical);
    if (!probe.open(QIODevice::ReadOnly))
        return QStringLiteral("Nie mogę otworzyć: ") + canonical;
    const QByteArray magic = probe.read(8);
    probe.close();

    const bool isJpeg = magic.startsWith("\xFF\xD8\xFF");
    const bool isPng = magic.startsWith("\x89PNG\r\n\x1A\n");
    // HEIF: brand "ftyp" na offset 4 + heic/mif1/heix; uproszczamy bez deep parsingu
    const bool isHeif = magic.size() >= 8 && magic.mid(4, 4) == "ftyp";
    if (!isJpeg && !isPng && !isHeif)
        return QStringLiteral("Plik nie jest obrazem (bad magic bytes)");

    return QString();   // OK
}

QString ApiClient::formatNetworkError(QNetworkReply *reply)
{
    if (!reply) return QStringLiteral("Nieznany błąd");

    const auto err = reply->error();
    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QString rawErrString = reply->errorString();
    const QString urlStr = reply->url().toString();

    // C-D04: peek body zamiast readAll() — funkcja ma być side-effect-free.
    // Caller może potem reply->readAll() dla diagnostyki bez ścierania bufora.
    // Cap 4096 — szukamy tylko FastAPI `detail`, nie potrzeba całego body.
    const QByteArray bodyPeek = reply->peek(4096);

    // C-D06: zawsze loguj triple (enum, HTTP, errorString, URL) niezależnie od ścieżki —
    // user widzi czysty komunikat, developer ma pełny kontekst w logcat.
    qWarning().nospace() << "[ApiClient] Net error: enum=" << err
                         << " http=" << httpStatus
                         << " errStr=\"" << rawErrString
                         << "\" url=" << urlStr;

    // FastAPI `detail` z body — najbardziej konkretny komunikat (jeśli serwer odpowiedział).
    if (!bodyPeek.isEmpty()) {
        const QJsonDocument doc = QJsonDocument::fromJson(bodyPeek);
        if (doc.isObject() && doc.object().contains(QStringLiteral("detail"))) {
            const QJsonValue det = doc.object().value(QStringLiteral("detail"));
            if (det.isString()) return det.toString();
            return QString::fromUtf8(QJsonDocument(det.toArray()).toJson(QJsonDocument::Compact));
        }
    }

    switch (err) {
    case QNetworkReply::NoError:
        return QString();
    case QNetworkReply::ConnectionRefusedError:
        return QStringLiteral("Backend nie odpowiada (wyłączony? sprawdź adres)");
    case QNetworkReply::RemoteHostClosedError:
        return QStringLiteral("Backend zerwał połączenie");
    case QNetworkReply::HostNotFoundError:
        return QStringLiteral("Nie znaleziono serwera — sprawdź URL w Ustawieniach");
    case QNetworkReply::TimeoutError:
    case QNetworkReply::OperationCanceledError:
        return QStringLiteral("Przekroczono czas oczekiwania (timeout)");
    case QNetworkReply::SslHandshakeFailedError:
        return QStringLiteral("Błąd TLS/SSL — certyfikat serwera nieważny");
    case QNetworkReply::NetworkSessionFailedError:
    case QNetworkReply::TemporaryNetworkFailureError:
        return QStringLiteral("Brak połączenia — sprawdź Wi-Fi/LTE");
    case QNetworkReply::AuthenticationRequiredError:
        return QStringLiteral("Niepoprawny token API (401) — sprawdź Ustawienia");
    case QNetworkReply::ContentAccessDenied:
        return QStringLiteral("Dostęp zabroniony (403)");
    case QNetworkReply::ContentNotFoundError:
        return QStringLiteral("Nie znaleziono zasobu (404)");
    default:
        // C-D06: default branch zawsze include errorString + numeric code w user message,
        // żeby field debugging na Androidzie nie był zgadywanką.
        if (httpStatus >= 500) {
            return QStringLiteral("Błąd serwera (HTTP %1): %2").arg(httpStatus).arg(rawErrString);
        }
        if (httpStatus > 0) {
            return QStringLiteral("HTTP %1: %2").arg(httpStatus).arg(rawErrString);
        }
        return QStringLiteral("Sieć: %1 (kod %2)").arg(rawErrString).arg(int(err));
    }
}

void ApiClient::checkHealth()
{
    const QUrl url(m_settings->apiUrl() + QStringLiteral("/health"));
    if (!url.isValid() || m_settings->apiUrl().isEmpty()) {
        emit healthError(QStringLiteral("Brak adresu backendu — wpisz URL w Ustawieniach"));
        return;
    }

    QNetworkRequest req = prepareRequest(QStringLiteral("/health"), 5s, /*withAuth*/false);
    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit healthError(formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            // L-04: walidacja — bez tego malformed JSON da puste {}.
            if (doc.isNull() || !doc.isObject()) {
                emit healthError(QStringLiteral("Niepoprawna odpowiedź serwera (JSON)"));
            } else {
                emit healthOk(doc.object().toVariantMap());
            }
        }
        reply->deleteLater();
    });
}

void ApiClient::sendMultipartPost(const QString &endpoint,
                                  const QString &photoPath,
                                  std::function<void(QNetworkReply *)> onFinish,
                                  std::chrono::milliseconds timeout)
{
    auto *file = new QFile(photoPath);
    if (!file->open(QIODevice::ReadOnly)) {
        qWarning() << "ApiClient: cannot open photo" << photoPath;
        QMetaObject::invokeMethod(
            this,
            [this]() { emit identifyError(QStringLiteral("Nie mogę otworzyć zdjęcia")); },
            Qt::QueuedConnection);
        delete file;
        return;
    }

    auto *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    QHttpPart imagePart;
    const QString filename = QFileInfo(photoPath).fileName();
    imagePart.setHeader(
        QNetworkRequest::ContentDispositionHeader,
        QVariant(QStringLiteral("form-data; name=\"images\"; filename=\"%1\"").arg(filename)));
    imagePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));
    imagePart.setBodyDevice(file);
    file->setParent(multi);
    multi->append(imagePart);

    QNetworkRequest req = prepareRequest(endpoint, timeout);
    QNetworkReply *reply = m_nam->post(req, multi);
    multi->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [reply, onFinish]() {
        onFinish(reply);
        reply->deleteLater();
    });
}

void ApiClient::identify(const QString &photoPath)
{
    qInfo() << "[ApiClient] identify" << photoPath;
    const QString err = validatePhotoPath(photoPath);
    if (!err.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, err]() { emit identifyError(err); }, Qt::QueuedConnection);
        return;
    }
    sendMultipartPost(
        QStringLiteral("/api/v1/identify"),
        photoPath,
        [this](QNetworkReply *reply) {
            if (reply->error() != QNetworkReply::NoError) {
                emit identifyError(formatNetworkError(reply));
                return;
            }
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit identifyError(QStringLiteral("Zła odpowiedź (brak JSON object)"));
                return;
            }
            emit identifyResult(doc.object().toVariantMap());
        },
        45s);  // Claude Opus ~10-25s realistic, 45s timeout margin
}

void ApiClient::findSimilar(const QString &photoPath, int topK)
{
    qInfo() << "[ApiClient] findSimilar" << photoPath << "top_k=" << topK;
    const QString verr = validatePhotoPath(photoPath);
    if (!verr.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, verr]() { emit similarError(verr); }, Qt::QueuedConnection);
        return;
    }

    // sendMultipartPost używa name="images" — dla /similar backend oczekuje name="image".
    // Dlatego robimy osobny POST tutaj, nie reużywamy sendMultipartPost.
    auto *file = new QFile(photoPath);
    if (!file->open(QIODevice::ReadOnly)) {
        emit similarError(QStringLiteral("Nie mogę otworzyć zdjęcia: ") + photoPath);
        delete file;
        return;
    }

    auto *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    QHttpPart imagePart;
    const QString filename = QFileInfo(photoPath).fileName();
    imagePart.setHeader(
        QNetworkRequest::ContentDispositionHeader,
        QVariant(QStringLiteral("form-data; name=\"image\"; filename=\"%1\"").arg(filename)));
    imagePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));
    imagePart.setBodyDevice(file);
    file->setParent(multi);
    multi->append(imagePart);

    QNetworkRequest req = prepareRequest(QStringLiteral("/api/v1/similar"), 20s);
    QUrl url = req.url();
    QUrlQuery q;
    q.addQueryItem("top_k", QString::number(topK));
    url.setQuery(q);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->post(req, multi);
    multi->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit similarError(formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            // L-04: walidacja — bez tego malformed response by zwrócił pustą listę.
            if (doc.isNull() || !doc.isObject()) {
                emit similarError(QStringLiteral("Niepoprawna odpowiedź serwera (JSON)"));
            } else {
                const QJsonObject obj = doc.object();
                const QVariantList list = obj.value("results").toArray().toVariantList();
                emit similarResult(list, obj.value("index_size").toInt());
            }
        }
        reply->deleteLater();
    });
}

void ApiClient::getExhibit(const QString &exhibitId)
{
    qInfo() << "[ApiClient] getExhibit" << exhibitId;
    QNetworkRequest req = prepareRequest(
        QStringLiteral("/api/v1/exhibits/") + exhibitId, 10s);
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, exhibitId]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitDetailError(formatNetworkError(reply), exhibitId);
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit exhibitDetailError(QStringLiteral("Zła odpowiedź"), exhibitId);
            } else {
                emit exhibitDetail(doc.object().toVariantMap());
            }
        }
        reply->deleteLater();
    });
}

void ApiClient::listExhibits(int page, int perPage)
{
    qInfo() << "[ApiClient] listExhibits page=" << page << "per_page=" << perPage;
    QNetworkRequest req = prepareRequest(QStringLiteral("/api/v1/exhibits"), 15s);
    QUrl url = req.url();
    QUrlQuery q;
    q.addQueryItem("page", QString::number(page));
    q.addQueryItem("per_page", QString::number(perPage));
    url.setQuery(q);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitListError(formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit exhibitListError(QStringLiteral("Zła odpowiedź"));
            } else {
                emit exhibitListResult(doc.object().toVariantMap());
            }
        }
        reply->deleteLater();
    });
}

void ApiClient::saveExhibit(const QVariantMap &payload, const QString &photoPath)
{
    qInfo() << "[ApiClient] saveExhibit" << payload.value("name") << "photo:" << photoPath;
    const QString verr = validatePhotoPath(photoPath);
    if (!verr.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, verr]() { emit exhibitError(verr); }, Qt::QueuedConnection);
        return;
    }

    // C-D02: multipart zamiast base64-in-JSON. Plik jest streamowany przez Qt
    // (QFile setBodyDevice), nie ładowany całością do RAM + 33% base64 overhead.
    // Dla 8 MB JPEG: dawniej ~25-30 MB transient heap, teraz ~8 MB raw + chunki.
    auto *file = new QFile(photoPath);
    if (!file->open(QIODevice::ReadOnly)) {
        QMetaObject::invokeMethod(this,
            [this, photoPath]() { emit exhibitError(QStringLiteral("Nie mogę otworzyć zdjęcia: ") + photoPath); },
            Qt::QueuedConnection);
        delete file;
        return;
    }

    auto *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    // Form fields — wszystkie oprócz photos
    for (auto it = payload.constBegin(); it != payload.constEnd(); ++it) {
        const QString key = it.key();
        const QVariant val = it.value();
        if (val.isNull() || !val.isValid())
            continue;

        QHttpPart part;
        part.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QVariant(QStringLiteral("form-data; name=\"%1\"").arg(key)));
        // FastAPI Form() akceptuje boolean jako "true"/"false", liczby jako string
        QString text;
        if (val.typeId() == QMetaType::Bool) {
            text = val.toBool() ? QStringLiteral("true") : QStringLiteral("false");
        } else {
            text = val.toString();
        }
        part.setBody(text.toUtf8());
        multi->append(part);
    }

    // Photo
    QHttpPart photoPart;
    const QString filename = QFileInfo(photoPath).fileName();
    photoPart.setHeader(QNetworkRequest::ContentDispositionHeader,
        QVariant(QStringLiteral("form-data; name=\"photos\"; filename=\"%1\"").arg(filename)));
    photoPart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));
    photoPart.setBodyDevice(file);
    file->setParent(multi);
    multi->append(photoPart);

    QNetworkRequest req = prepareRequest(
        QStringLiteral("/api/v1/exhibits/multipart"), 30s);
    QNetworkReply *reply = m_nam->post(req, multi);
    multi->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitError(formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit exhibitError(QStringLiteral("Zła odpowiedź serwera"));
            } else {
                const QJsonObject obj = doc.object();
                emit exhibitSaved(obj.value("id").toString(),
                                  obj.value("photos_count").toInt());
            }
        }
        reply->deleteLater();
    });
}
