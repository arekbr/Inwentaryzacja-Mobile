#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "ApiClient.h"
#include "AppSettings.h"
#include "CameraIntent.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Inwentaryzacja Mobile");
    QGuiApplication::setOrganizationName("bronkibrothers");
    QGuiApplication::setOrganizationDomain("bronkibrothers.com");

    // Android 16 / Pixel 10 Pro:
    //   Material  → broken GPU (tęczowe paski, czarny Image)
    //   Basic     → garbled content (TextField/ScrollView render chaos)
    //   Fusion    → pure-Qt drawing, bez systemowych regresji
    QQuickStyle::setStyle("Fusion");

    CameraIntent cameraIntent;
    AppSettings appSettings;
    ApiClient apiClient(&appSettings);

    QQmlApplicationEngine engine;
    auto *ctx = engine.rootContext();
    ctx->setContextProperty("cameraIntent", &cameraIntent);
    ctx->setContextProperty("appSettings", &appSettings);
    ctx->setContextProperty("apiClient", &apiClient);

    engine.loadFromModule("App", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
