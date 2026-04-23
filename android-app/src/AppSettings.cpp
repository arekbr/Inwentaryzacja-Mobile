#include "AppSettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_ANDROID
    // Security tradeoff: on Android trzymaj token tylko w pamięci procesu.
    // Nie zapisuj do SharedPreferences/QSettings, żeby nie lądował plaintextem
    // na urządzeniu i nie był objęty systemowym backup/restore.
    m_apiToken = QString();
#endif
}

QString AppSettings::apiUrl() const
{
    return m_settings.value(QStringLiteral("apiUrl"),
                            QStringLiteral("http://192.168.1.100:8000")).toString();
}

void AppSettings::setApiUrl(const QString &url)
{
    if (url == apiUrl())
        return;
    m_settings.setValue(QStringLiteral("apiUrl"), url);
    emit apiUrlChanged();
}

QString AppSettings::apiToken() const
{
#ifdef Q_OS_ANDROID
    return m_apiToken;
#else
    return m_settings.value(QStringLiteral("apiToken"), QString()).toString();
#endif
}

void AppSettings::setApiToken(const QString &token)
{
    if (token == apiToken())
        return;
#ifdef Q_OS_ANDROID
    m_apiToken = token;
#else
    m_settings.setValue(QStringLiteral("apiToken"), token);
#endif
    emit apiTokenChanged();
}
