#include "ApiClient.h"
#include "AppSettings.h"

#include <QBuffer>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QHttpPart>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSslError>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

#include <memory>

namespace {
// Q-05: krotki UUID (8 znakow) dla logow czytelnosci, kolizja
// w ramach 1 user session praktycznie 0.
QString newRequestId() {
    return QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
}

// Resize zdjecia PRZED uploadem: 50MP foto z Pixela (~12-15 MB) -> ~300-500 KB JPEG.
// Powod: timeout uploadu, baza nie puchnie do 13 GB, szybszy CLIP/thumbnail na backendzie.
// Zwraca pusty QByteArray na blad (caller raportuje).
QByteArray loadAndResizePhoto(const QString &path, int maxDim = 2048, int quality = 85) {
    QImageReader reader(path);
    reader.setAutoTransform(true);  // honor EXIF orientation
    QImage img = reader.read();
    if (img.isNull()) {
        qWarning() << "[ApiClient] resize: nie moge zdekodowac" << path << reader.errorString();
        return {};
    }

    if (img.width() > maxDim || img.height() > maxDim) {
        img = img.scaled(maxDim, maxDim, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    QByteArray out;
    QBuffer buf(&out);
    buf.open(QIODevice::WriteOnly);
    if (!img.save(&buf, "JPEG", quality)) {
        qWarning() << "[ApiClient] resize: JPEG encode failed";
        return {};
    }
    qInfo() << "[ApiClient] resize:" << path << "->" << out.size() << "B (max" << maxDim << "px, q" << quality << ")";
    return out;
}
}

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

QString ApiClient::formatNetworkError(QNetworkReply *reply)  // C-D09: nie-static
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
        // C-D09 wariant A: emit sygnal zeby QML mogl auto-nawigowac do Ustawien.
        // Token jest sessional na Androidzie (security tier-1.5), wiec po restart
        // user musi wpisac ponownie. UI powinno go tam dowiezc.
        emit tokenRequired();
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

QString ApiClient::checkHealth()
{
    const QString rid = newRequestId();  // Q-05
    const QUrl url(m_settings->apiUrl() + QStringLiteral("/health"));
    if (!url.isValid() || m_settings->apiUrl().isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, rid]() { emit healthError(rid, QStringLiteral("Brak adresu backendu — wpisz URL w Ustawieniach")); },
            Qt::QueuedConnection);
        return rid;
    }

    QNetworkRequest req = prepareRequest(QStringLiteral("/health"), 5s, /*withAuth*/false);
    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, rid]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit healthError(rid, formatNetworkError(reply));
            reply->deleteLater();
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        reply->deleteLater();
        if (doc.isNull() || !doc.isObject()) {
            emit healthError(rid, QStringLiteral("Niepoprawna odpowiedź serwera (JSON)"));
            return;
        }
        const QVariantMap info = doc.object().toVariantMap();

        // Bug-fix: /health jest publiczny (200 bez tokenu). Bez drugiego sprawdzenia
        // welcome świeci zielono nawet z błędnym tokenem, a user widzi 401 dopiero
        // przy wyszukiwaniu/zapisie. Drugi GET na chroniony /dictionaries weryfikuje token.
        if (m_settings->apiToken().isEmpty()) {
            emit healthOk(rid, info);
            return;
        }
        QNetworkRequest authReq = prepareRequest(
            QStringLiteral("/api/v1/dictionaries/types"), 5s, /*withAuth*/true);
        QNetworkReply *authReply = m_nam->get(authReq);
        connect(authReply, &QNetworkReply::finished, this, [this, authReply, rid, info]() {
            const int status = authReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (authReply->error() == QNetworkReply::NoError) {
                emit healthOk(rid, info);
            } else if (status == 401 || authReply->error() == QNetworkReply::AuthenticationRequiredError) {
                emit tokenRequired();
                emit healthError(rid, QStringLiteral("Backend OK, ale token niepoprawny — sprawdź Ustawienia"));
            } else {
                // Inne błędy (5xx, sieć) — backend działa health, ale dictionaries padło.
                emit healthError(rid, QStringLiteral("Backend działa, ale weryfikacja tokenu nieudana: ")
                                      + formatNetworkError(authReply));
            }
            authReply->deleteLater();
        });
    });
    return rid;
}

void ApiClient::sendMultipartPost(const QString &endpoint,
                                  const QString &photoPath,
                                  std::function<void(QNetworkReply *)> onFinish,
                                  std::function<void(const QString &)> onError,
                                  std::chrono::milliseconds timeout)
{
    // Resize PRZED uploadem (50MP Pixel -> ~400 KB JPEG).
    const QByteArray bytes = loadAndResizePhoto(photoPath);
    if (bytes.isEmpty()) {
        QMetaObject::invokeMethod(
            this,
            [onError]() { onError(QStringLiteral("Nie mogę zdekodować/zmniejszyć zdjęcia")); },
            Qt::QueuedConnection);
        return;
    }

    auto multi = std::make_unique<QHttpMultiPart>(QHttpMultiPart::FormDataType);
    QHttpPart imagePart;
    const QString filename = QFileInfo(photoPath).completeBaseName() + QStringLiteral(".jpg");
    imagePart.setHeader(
        QNetworkRequest::ContentDispositionHeader,
        QVariant(QStringLiteral("form-data; name=\"images\"; filename=\"%1\"").arg(filename)));
    imagePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));
    imagePart.setBody(bytes);
    multi->append(imagePart);

    QNetworkRequest req = prepareRequest(endpoint, timeout);
    QNetworkReply *reply = m_nam->post(req, multi.get());
    multi.release()->setParent(reply);  // ownership: reply → multi

    connect(reply, &QNetworkReply::finished, this, [reply, onFinish]() {
        onFinish(reply);
        reply->deleteLater();
    });
}

QString ApiClient::identify(const QString &photoPath)
{
    const QString rid = newRequestId();  // Q-05
    qInfo() << "[ApiClient] identify rid=" << rid << photoPath;
    const QString err = validatePhotoPath(photoPath);
    if (!err.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, rid, err]() { emit identifyError(rid, err); }, Qt::QueuedConnection);
        return rid;
    }
    sendMultipartPost(
        QStringLiteral("/api/v1/identify"),
        photoPath,
        [this, rid](QNetworkReply *reply) {
            if (reply->error() != QNetworkReply::NoError) {
                emit identifyError(rid, formatNetworkError(reply));
                return;
            }
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit identifyError(rid, QStringLiteral("Zła odpowiedź (brak JSON object)"));
                return;
            }
            emit identifyResult(rid, doc.object().toVariantMap());
        },
        [this, rid](const QString &msg) { emit identifyError(rid, msg); },
        45s);
    return rid;
}

QString ApiClient::findSimilar(const QString &photoPath, int topK)
{
    const QString rid = newRequestId();  // Q-05
    qInfo() << "[ApiClient] findSimilar rid=" << rid << photoPath << "top_k=" << topK;
    const QString verr = validatePhotoPath(photoPath);
    if (!verr.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, rid, verr]() { emit similarError(rid, verr); }, Qt::QueuedConnection);
        return rid;
    }

    // sendMultipartPost używa name="images" — dla /similar backend oczekuje name="image".
    // Dlatego robimy osobny POST tutaj, nie reużywamy sendMultipartPost.
    const QByteArray bytes = loadAndResizePhoto(photoPath);
    if (bytes.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, rid, photoPath]() { emit similarError(rid, QStringLiteral("Nie mogę zdekodować/zmniejszyć zdjęcia: ") + photoPath); },
            Qt::QueuedConnection);
        return rid;
    }

    auto multi = std::make_unique<QHttpMultiPart>(QHttpMultiPart::FormDataType);
    QHttpPart imagePart;
    const QString filename = QFileInfo(photoPath).completeBaseName() + QStringLiteral(".jpg");
    imagePart.setHeader(
        QNetworkRequest::ContentDispositionHeader,
        QVariant(QStringLiteral("form-data; name=\"image\"; filename=\"%1\"").arg(filename)));
    imagePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));
    imagePart.setBody(bytes);
    multi->append(imagePart);

    QNetworkRequest req = prepareRequest(QStringLiteral("/api/v1/similar"), 20s);
    QUrl url = req.url();
    QUrlQuery q;
    q.addQueryItem("top_k", QString::number(topK));
    url.setQuery(q);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->post(req, multi.get());
    multi.release()->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, rid]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit similarError(rid, formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (doc.isNull() || !doc.isObject()) {
                emit similarError(rid, QStringLiteral("Niepoprawna odpowiedź serwera (JSON)"));
            } else {
                const QJsonObject obj = doc.object();
                const QVariantList list = obj.value("results").toArray().toVariantList();
                emit similarResult(rid, list, obj.value("index_size").toInt());
            }
        }
        reply->deleteLater();
    });
    return rid;
}

QString ApiClient::getExhibit(const QString &exhibitId)
{
    const QString rid = newRequestId();  // Q-05
    qInfo() << "[ApiClient] getExhibit rid=" << rid << exhibitId;
    QNetworkRequest req = prepareRequest(
        QStringLiteral("/api/v1/exhibits/") + exhibitId, 10s);
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, rid]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitDetailError(rid, formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit exhibitDetailError(rid, QStringLiteral("Zła odpowiedź"));
            } else {
                emit exhibitDetail(rid, doc.object().toVariantMap());
            }
        }
        reply->deleteLater();
    });
    return rid;
}

QString ApiClient::listExhibits(int page, int perPage)
{
    const QString rid = newRequestId();  // Q-05
    qInfo() << "[ApiClient] listExhibits rid=" << rid << "page=" << page << "per_page=" << perPage;
    QNetworkRequest req = prepareRequest(QStringLiteral("/api/v1/exhibits"), 15s);
    QUrl url = req.url();
    QUrlQuery q;
    q.addQueryItem("page", QString::number(page));
    q.addQueryItem("per_page", QString::number(perPage));
    url.setQuery(q);
    req.setUrl(url);

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, rid]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitListError(rid, formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit exhibitListError(rid, QStringLiteral("Zła odpowiedź"));
            } else {
                emit exhibitListResult(rid, doc.object().toVariantMap());
            }
        }
        reply->deleteLater();
    });
    return rid;
}

QString ApiClient::saveExhibit(const QVariantMap &payload, const QString &photoPath)
{
    const QString rid = newRequestId();  // Q-05
    qInfo() << "[ApiClient] saveExhibit rid=" << rid << payload.value("name") << "photo:" << photoPath;
    const QString verr = validatePhotoPath(photoPath);
    if (!verr.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, rid, verr]() { emit exhibitError(rid, verr); }, Qt::QueuedConnection);
        return rid;
    }

    // C-D02: multipart zamiast base64-in-JSON. Dodatkowo resize PRZED uploadem:
    // 50MP Pixel (~12-15 MB) -> ~400 KB JPEG. Powod: timeout, baza nie puchnie do 13 GB,
    // szybsza similarity search.
    const QByteArray bytes = loadAndResizePhoto(photoPath);
    if (bytes.isEmpty()) {
        QMetaObject::invokeMethod(this,
            [this, rid, photoPath]() { emit exhibitError(rid, QStringLiteral("Nie mogę zdekodować/zmniejszyć zdjęcia: ") + photoPath); },
            Qt::QueuedConnection);
        return rid;
    }

    auto multi = std::make_unique<QHttpMultiPart>(QHttpMultiPart::FormDataType);

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
    const QString filename = QFileInfo(photoPath).completeBaseName() + QStringLiteral(".jpg");
    photoPart.setHeader(QNetworkRequest::ContentDispositionHeader,
        QVariant(QStringLiteral("form-data; name=\"photos\"; filename=\"%1\"").arg(filename)));
    photoPart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant("image/jpeg"));
    photoPart.setBody(bytes);
    multi->append(photoPart);

    QNetworkRequest req = prepareRequest(
        QStringLiteral("/api/v1/exhibits/multipart"), 30s);
    QNetworkReply *reply = m_nam->post(req, multi.get());
    multi.release()->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, rid]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitError(rid, formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit exhibitError(rid, QStringLiteral("Zła odpowiedź serwera"));
            } else {
                const QJsonObject obj = doc.object();
                emit exhibitSaved(rid, obj.value("id").toString(),
                                  obj.value("photos_count").toInt());
            }
        }
        reply->deleteLater();
    });
    return rid;
}
