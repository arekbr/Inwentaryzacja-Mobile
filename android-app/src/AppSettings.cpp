#include "AppSettings.h"

#include <QUrl>

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    // Tier-1.6: token persystowany w QSettings (per-app sandbox /data/data/<pkg>/).
    // android:allowBackup="false" w manifescie blokuje cloud/adb backup leak.
    // Tier-2 plan: Android Keystore (EncryptedSharedPreferences) — patrz docs/architecture.md.
    // C-D08: warm cache — read raz na start, nie per-call.
    m_apiUrlCache = m_settings.value(QStringLiteral("apiUrl"),
                                     QStringLiteral("http://192.168.1.100:8000")).toString();
}

QString AppSettings::apiUrl() const
{
    return m_apiUrlCache;
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
    m_apiUrlCache = trimmed;  // C-D08: invalidate cache po setValue
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
