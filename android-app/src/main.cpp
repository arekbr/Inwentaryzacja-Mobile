#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "CameraIntent.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Inwentaryzacja Mobile");
    QGuiApplication::setOrganizationName("bronkibrothers");
    QGuiApplication::setOrganizationDomain("bronkibrothers.com");

    // Material na Android 16 / Pixel 10 Pro ma broken GPU renderer (tęczowe paski,
    // Image z czarnym tłem mimo Ready). Używamy Basic jako bezpieczny fallback.
    QQuickStyle::setStyle("Basic");

    CameraIntent cameraIntent;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("cameraIntent", &cameraIntent);
    engine.loadFromModule("App", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
