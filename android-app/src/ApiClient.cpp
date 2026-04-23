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
#include <QUrl>
#include <QUrlQuery>

ApiClient::ApiClient(AppSettings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_nam(new QNetworkAccessManager(this))
{
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
            emit healthOk(doc.object().toVariantMap());
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
            const QJsonObject obj = doc.object();
            const QVariantList list = obj.value("results").toArray().toVariantList();
            emit similarResult(list, obj.value("index_size").toInt());
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
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitDetailError(formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit exhibitDetailError(QStringLiteral("Zła odpowiedź"));
            } else {
                emit exhibitDetail(doc.object().toVariantMap());
            }
        }
        reply->deleteLater();
    });
}

void ApiClient::saveExhibit(const QVariantMap &payload, const QString &photoPath)
{
    qInfo() << "[ApiClient] saveExhibit" << payload.value("name") << "photo:" << photoPath;

    // Wczytaj zdjęcie i zakoduj do base64
    QFile file(photoPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit exhibitError(QStringLiteral("Nie mogę otworzyć zdjęcia: ") + photoPath);
        return;
    }
    const QByteArray photoB64 = file.readAll().toBase64();
    file.close();

    // Zbuduj JSON body
    QJsonObject body = QJsonObject::fromVariantMap(payload);
    body["photos_base64"] = QJsonArray{QString::fromLatin1(photoB64)};

    const QUrl url(m_settings->apiUrl() + QStringLiteral("/api/v1/exhibits"));
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setTransferTimeout(30000);  // base64 photo upload + DB write
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

    QNetworkReply *reply = m_nam->post(req, QJsonDocument(body).toJson());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit exhibitError(formatNetworkError(reply));
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            const QJsonObject obj = doc.object();
            emit exhibitSaved(obj.value("id").toString(),
                              obj.value("photos_count").toInt());
        }
        reply->deleteLater();
    });
}
