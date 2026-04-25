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

QString ApiClient::formatNetworkError(QNetworkReply *reply)
{
    if (!reply) return QStringLiteral("Nieznany błąd");

    // Najpierw FastAPI `detail` z body — najbardziej konkretny komunikat.
    const QByteArray body = reply->readAll();
    if (!body.isEmpty()) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        if (doc.isObject() && doc.object().contains("detail")) {
            const QJsonValue det = doc.object().value("detail");
            if (det.isString()) return det.toString();
            return QString::fromUtf8(QJsonDocument(det.toArray()).toJson(QJsonDocument::Compact));
        }
    }

    const auto err = reply->error();
    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

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
        if (httpStatus >= 500) return QStringLiteral("Błąd serwera (HTTP %1)").arg(httpStatus);
        if (httpStatus > 0)   return QStringLiteral("HTTP %1: %2").arg(httpStatus).arg(reply->errorString());
        return QStringLiteral("Nie można połączyć się z serwerem — sprawdź adres i sieć");
    }
}

void ApiClient::checkHealth()
{
    const QUrl url(m_settings->apiUrl() + QStringLiteral("/health"));
    if (!url.isValid() || m_settings->apiUrl().isEmpty()) {
        emit healthError(QStringLiteral("Brak adresu backendu — wpisz URL w Ustawieniach"));
        return;
    }

    QNetworkRequest req(url);
    req.setTransferTimeout(5000);   // health ma być szybki
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
                                  int timeoutMs)
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

    const QUrl url(m_settings->apiUrl() + endpoint);
    QNetworkRequest req(url);
    req.setTransferTimeout(timeoutMs);
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

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
        45000);  // Claude Opus ~10-25s realistic, 45s timeout margin
}

void ApiClient::findSimilar(const QString &photoPath, int topK)
{
    qInfo() << "[ApiClient] findSimilar" << photoPath << "top_k=" << topK;

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

    QUrl url(m_settings->apiUrl() + QStringLiteral("/api/v1/similar"));
    QUrlQuery q;
    q.addQueryItem("top_k", QString::number(topK));
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setTransferTimeout(20000);  // CLIP ~0.5s + thumbs + upload
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

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
    const QUrl url(m_settings->apiUrl() + QStringLiteral("/api/v1/exhibits/") + exhibitId);
    QNetworkRequest req(url);
    req.setTransferTimeout(10000);
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

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
    QUrl url(m_settings->apiUrl() + QStringLiteral("/api/v1/exhibits"));
    QUrlQuery q;
    q.addQueryItem("page", QString::number(page));
    q.addQueryItem("per_page", QString::number(perPage));
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setTransferTimeout(15000);  // miniatury per page mogą zająć chwilę przy 50× JPEG
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

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

    const QUrl url(m_settings->apiUrl() + QStringLiteral("/api/v1/exhibits/multipart"));
    QNetworkRequest req(url);
    req.setTransferTimeout(30000);
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

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
