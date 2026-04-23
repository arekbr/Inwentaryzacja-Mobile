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

signals:
    void apiUrlChanged();
    void apiTokenChanged();

private:
    QSettings m_settings;
#ifdef Q_OS_ANDROID
    QString m_apiToken;
#endif
};
