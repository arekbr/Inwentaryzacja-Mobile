#include "CameraIntent.h"

#include <QDebug>

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>
#include <jni.h>
#endif

std::atomic<CameraIntent *> CameraIntent::s_instance{nullptr};

CameraIntent::CameraIntent(QObject *parent)
    : QObject(parent)
{
    // C-D01: enforce singleton invariant — exchange wymaga że poprzednia wartość była null.
    CameraIntent *expected = nullptr;
    if (!s_instance.compare_exchange_strong(expected, this, std::memory_order_release)) {
        qFatal("CameraIntent: druga instancja konstruowana podczas gdy poprzednia żyje (s_instance=%p). "
               "JNI callbacks dostają tylko jeden cel — wieloinstancyjność jest błędem programisty.",
               expected);
    }
}

CameraIntent::~CameraIntent()
{
    CameraIntent *expected = this;
    s_instance.compare_exchange_strong(expected, nullptr, std::memory_order_release);
}

CameraIntent *CameraIntent::instance()
{
    return s_instance.load(std::memory_order_acquire);
}

void CameraIntent::launch()
{
#ifdef Q_OS_ANDROID
    QJniObject activity(QNativeInterface::QAndroidApplication::context());
    if (!activity.isValid()) {
        qWarning() << "CameraIntent: invalid Android context";
        emit photoError(QStringLiteral("Brak kontekstu Android"));
        return;
    }
    activity.callMethod<void>("launchCamera");
#else
    qWarning() << "CameraIntent::launch() — tylko Android ma implementację";
    emit photoError(QStringLiteral("Camera intent dostępny tylko na Android"));
#endif
}

#ifdef Q_OS_ANDROID

static QString jstringToQString(JNIEnv *env, jstring s)
{
    if (!s)
        return {};
    const char *utf = env->GetStringUTFChars(s, nullptr);
    QString q = QString::fromUtf8(utf);
    env->ReleaseStringUTFChars(s, utf);
    return q;
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_bronkibrothers_inwentaryzacja_mobile_MainActivity_nativeOnPhotoCaptured(
    JNIEnv *env, jclass, jstring path)
{
    const QString qpath = jstringToQString(env, path);
    qInfo() << "[CameraIntent] photo captured:" << qpath;
    if (auto *inst = CameraIntent::instance()) {
        QMetaObject::invokeMethod(
            inst,
            [inst, qpath]() { emit inst->photoCaptured(qpath); },
            Qt::QueuedConnection);
    }
}

JNIEXPORT void JNICALL
Java_com_bronkibrothers_inwentaryzacja_mobile_MainActivity_nativeOnPhotoError(
    JNIEnv *env, jclass, jstring msg)
{
    const QString qmsg = jstringToQString(env, msg);
    qWarning() << "[CameraIntent] photo error:" << qmsg;
    if (auto *inst = CameraIntent::instance()) {
        QMetaObject::invokeMethod(
            inst,
            [inst, qmsg]() { emit inst->photoError(qmsg); },
            Qt::QueuedConnection);
    }
}

} // extern "C"

#endif
