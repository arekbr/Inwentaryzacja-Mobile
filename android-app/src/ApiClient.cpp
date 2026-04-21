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

void ApiClient::checkHealth()
{
    const QUrl url(m_settings->apiUrl() + QStringLiteral("/health"));
    if (!url.isValid()) {
        emit healthError(QStringLiteral("Nieprawidłowy URL: ") + url.toString());
        return;
    }

    QNetworkRequest req(url);
    QNetworkReply *reply = m_nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit healthError(reply->errorString());
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            const QJsonObject obj = doc.object();
            emit healthOk(obj.value("version").toString(),
                          obj.value("database").toString());
        }
        reply->deleteLater();
    });
}

void ApiClient::sendMultipartPost(const QString &endpoint,
                                  const QString &photoPath,
                                  std::function<void(QNetworkReply *)> onFinish)
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
                const QByteArray body = reply->readAll();
                QString msg = reply->errorString();
                if (!body.isEmpty()) {
                    const QJsonDocument doc = QJsonDocument::fromJson(body);
                    if (doc.isObject() && doc.object().contains("detail"))
                        msg += ": " + doc.object().value("detail").toString();
                }
                emit identifyError(msg);
                return;
            }
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            if (!doc.isObject()) {
                emit identifyError(QStringLiteral("Zła odpowiedź (brak JSON object)"));
                return;
            }
            emit identifyResult(doc.object().toVariantMap());
        });
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
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

    QNetworkReply *reply = m_nam->post(req, multi);
    multi->setParent(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            const QByteArray body = reply->readAll();
            QString msg = reply->errorString();
            if (!body.isEmpty()) {
                const QJsonDocument doc = QJsonDocument::fromJson(body);
                if (doc.isObject() && doc.object().contains("detail"))
                    msg += ": " + doc.object().value("detail").toString();
            }
            emit similarError(msg);
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
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            const QByteArray body = reply->readAll();
            QString msg = reply->errorString();
            if (!body.isEmpty()) {
                const QJsonDocument doc = QJsonDocument::fromJson(body);
                if (doc.isObject() && doc.object().contains("detail"))
                    msg += ": " + doc.object().value("detail").toString();
            }
            emit exhibitDetailError(msg);
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
    if (!m_settings->apiToken().isEmpty()) {
        req.setRawHeader("Authorization",
                         ("Bearer " + m_settings->apiToken()).toUtf8());
    }

    QNetworkReply *reply = m_nam->post(req, QJsonDocument(body).toJson());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            const QByteArray errBody = reply->readAll();
            QString msg = reply->errorString();
            if (!errBody.isEmpty()) {
                const QJsonDocument errDoc = QJsonDocument::fromJson(errBody);
                if (errDoc.isObject() && errDoc.object().contains("detail")) {
                    const QJsonValue det = errDoc.object().value("detail");
                    msg += ": " + (det.isString() ? det.toString()
                                                  : QString::fromUtf8(QJsonDocument(det.toArray()).toJson(QJsonDocument::Compact)));
                }
            }
            emit exhibitError(msg);
        } else {
            const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
            const QJsonObject obj = doc.object();
            emit exhibitSaved(obj.value("id").toString(),
                              obj.value("photos_count").toInt());
        }
        reply->deleteLater();
    });
}
