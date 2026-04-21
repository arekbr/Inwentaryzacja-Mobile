#pragma once

#include <QObject>
#include <QVariantMap>

class AppSettings;
class QNetworkAccessManager;
class QNetworkReply;

/**
 * HTTP client do FastAPI backendu (identify/similar/exhibits/dictionaries).
 * Zarejestrowany jako context property `apiClient` w QML.
 *
 * Wszystkie metody async, wyniki przez sygnały.
 */
class ApiClient : public QObject
{
    Q_OBJECT
public:
    explicit ApiClient(AppSettings *settings, QObject *parent = nullptr);

    /// Health probe — GET /health. Sprawdza czy API odpowiada.
    Q_INVOKABLE void checkHealth();

    /// POST /api/v1/identify — multipart z JPG. Wynik → identifyResult(artefakt).
    Q_INVOKABLE void identify(const QString &photoPath);

    /// POST /api/v1/exhibits — JSON z polami Artefakt + base64 zdjęcia.
    /// @param payload mapa pól (name, type, vendor, model, ...)
    /// @param photoPath ścieżka do JPG (odczytany i zakodowany do base64)
    Q_INVOKABLE void saveExhibit(const QVariantMap &payload, const QString &photoPath);

signals:
    void healthOk(const QString &version, const QString &database);
    void healthError(const QString &message);

    void identifyResult(const QVariantMap &artefakt);
    void identifyError(const QString &message);

    void exhibitSaved(const QString &id, int photosCount);
    void exhibitError(const QString &message);

private:
    void sendMultipartPost(const QString &endpoint,
                           const QString &photoPath,
                           std::function<void(QNetworkReply *)> onFinish);

    AppSettings *m_settings;
    QNetworkAccessManager *m_nam;
};
