#include "AppSettings.h"

#include <QUrl>

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

bool AppSettings::isValidApiUrl(const QString &url)
{
    // Pusty = OK (default state, nie pokazuj błędu zanim user zacznie pisać).
    if (url.isEmpty())
        return true;
    const QUrl u = QUrl::fromUserInput(url.trimmed());
    if (!u.isValid())
        return false;
    if (u.scheme() != QStringLiteral("http") && u.scheme() != QStringLiteral("https"))
        return false;
    if (u.host().isEmpty())
        return false;
    return true;
}

void AppSettings::setApiUrl(const QString &url)
{
    // C-D05: odrzuć malformed/wrong-scheme URL z emitem apiUrlInvalid.
    // Bez tego user może wkleić "htttp://" z literówką i ApiClient
    // konstruuje broken QNetworkRequest z obscure failures.
    const QString trimmed = url.trimmed();
    if (!isValidApiUrl(trimmed)) {
        emit apiUrlInvalid(trimmed, QStringLiteral("Wymagane http:// lub https:// + host"));
        return;
    }
    if (trimmed == apiUrl())
        return;
    m_settings.setValue(QStringLiteral("apiUrl"), trimmed);
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
