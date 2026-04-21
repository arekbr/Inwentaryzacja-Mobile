#include "AppSettings.h"

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
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
    return m_settings.value(QStringLiteral("apiToken"), QString()).toString();
}

void AppSettings::setApiToken(const QString &token)
{
    if (token == apiToken())
        return;
    m_settings.setValue(QStringLiteral("apiToken"), token);
    emit apiTokenChanged();
}
