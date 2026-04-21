#pragma once

#include <QObject>
#include <QString>

/**
 * Most do natywnej aplikacji Camera na Androidzie. Na innych platformach (macOS dev host)
 * tylko stuby — QML pokazuje komunikat.
 *
 * Użycie z QML (zarejestrowany jako context property `cameraIntent`):
 *
 *     Button {
 *         onClicked: cameraIntent.launch()
 *     }
 *     Connections {
 *         target: cameraIntent
 *         function onPhotoCaptured(path) { ... }
 *         function onPhotoError(msg) { ... }
 *     }
 */
class CameraIntent : public QObject
{
    Q_OBJECT
public:
    explicit CameraIntent(QObject *parent = nullptr);
    ~CameraIntent() override;

    static CameraIntent *instance();

    Q_INVOKABLE void launch();

signals:
    void photoCaptured(const QString &path);
    void photoError(const QString &message);

private:
    static CameraIntent *s_instance;
};
