#include "ApiClient.h"
#include "AppSettings.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QHttpPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

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
