#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "ApiClient.h"
#include "AppSettings.h"
#include "CameraIntent.h"

int main(int argc, char *argv[])
{
    // Pixel 10 Pro / Android 16: po powrocie z Camera Intent system niszczy
    // Qt EGL surface (BufferQueue abandoned → "QRhiGles2: Failed to make
    // context current"). Threaded RHI/GLES2 SceneGraph trzyma stale ref do
    // destroyed surface i rysuje do martwej powierzchni — Image renderuje
    // się jako pustka, mimo Image.Ready=true i poprawnego paintedSize.
    // Workaround: basic render loop (single-threaded, CPU-driven) toleruje
    // surface tear-down i re-creates context przy następnym paint event.
    // Trade-off: drobne spadki FPS w animacjach — niezauważalne dla apki
    // z formularzami i statycznymi obrazami.
    qputenv("QSG_RENDER_LOOP", "basic");

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
