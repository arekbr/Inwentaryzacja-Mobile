#pragma once

#include <QObject>
#include <QSettings>
#include <QString>

/**
 * Persistent ustawienia apki (API URL, Bearer token). Trzymane w QSettings —
 * na Androidzie = SharedPreferences. Wystawione do QML jako context property.
 */
class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiUrl READ apiUrl WRITE setApiUrl NOTIFY apiUrlChanged)
    Q_PROPERTY(QString apiToken READ apiToken WRITE setApiToken NOTIFY apiTokenChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString apiUrl() const;
    void setApiUrl(const QString &url);

    QString apiToken() const;
    void setApiToken(const QString &token);

    /// C-D05: walidator URL — zwraca true jeśli http(s)://host[:port][/path].
    /// Używany w SettingsPage (button "Test połączenia" disabled) + setApiUrl
    /// odrzuca invalid bez emitowania apiUrlChanged.
    Q_INVOKABLE static bool isValidApiUrl(const QString &url);

signals:
    void apiUrlChanged();
    void apiTokenChanged();
    /// Emitted gdy setApiUrl odrzucił URL (UI może pokazać feedback).
    void apiUrlInvalid(const QString &url, const QString &reason);

private:
    QSettings m_settings;
    /// C-D08: apiUrl() jest wywoływany w prepareRequest na każde żądanie HTTP
    /// (5+ razy w typowym flow zdjęcia). QSettings na Androidzie = SharedPreferences
    /// = JNI call + I/O — cache w pamięci eliminuje powtarzalny koszt.
    /// Invalidate w setApiUrl po setValue.
    mutable QString m_apiUrlCache;
#ifdef Q_OS_ANDROID
    QString m_apiToken;
#endif
};
