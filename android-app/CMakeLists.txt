cmake_minimum_required(VERSION 3.21)

project(InwentaryzacjaMobile
    VERSION 0.2.0
    DESCRIPTION "Mobilna apka Qt Android — katalogowanie eksponatów muzeum"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(InwentaryzacjaMobile
    src/main.cpp
    src/CameraIntent.cpp
    include/CameraIntent.h
    src/AppSettings.cpp
    include/AppSettings.h
    src/ApiClient.cpp
    include/ApiClient.h
)

target_include_directories(InwentaryzacjaMobile PRIVATE include)

qt_add_qml_module(InwentaryzacjaMobile
    URI App
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/CameraPage.qml
        qml/SettingsPage.qml
        qml/EditExhibitPage.qml
        qml/SimilarPage.qml
        qml/ExhibitDetailPage.qml
        qml/ExhibitListPage.qml
)

target_link_libraries(InwentaryzacjaMobile PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
)

# === Android-specific ===
if(ANDROID)
    # versionCode = liczba commitów + offset (monotonicznie rosnący).
    # Offset 10 zostawia margines na pierwsze 9 ręcznych uploadów do Play (1..9 użyte historycznie).
    execute_process(
        COMMAND git rev-list --count HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_COUNT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE GIT_RC
    )
    if(NOT GIT_RC EQUAL 0 OR NOT GIT_COMMIT_COUNT MATCHES "^[0-9]+$")
        message(WARNING "git rev-list failed (rc=${GIT_RC}), falling back to versionCode 100")
        set(GIT_COMMIT_COUNT 90)
    endif()
    math(EXPR ANDROID_VERSION_CODE "${GIT_COMMIT_COUNT} + 10")
    message(STATUS "Android versionCode: ${ANDROID_VERSION_CODE} (git commits: ${GIT_COMMIT_COUNT} + offset 10)")

    # 16 KB page size — Play wymaga dla targetSdk >= 35 (odrzuca aktualizacje bez tego od 1.02.2027).
    # NDK r27 NIE ustawia tego domyślnie (dopiero r28) — flagi jawne dla naszego .so.
    target_link_options(InwentaryzacjaMobile PRIVATE
        "-Wl,-z,max-page-size=16384"
        "-Wl,-z,common-page-size=16384"
    )

    # targetSdk 36 (Android 16): Play wymaga dla KAŻDEJ aktualizacji od 31.08.2026 (przedłużenie do 1.11.2026).
    # minSdk 28: dolna granica wspierana przez Qt 6.11 (Android 9). Wymaga Qt >= 6.10 (6.9 oficjalnie tylko do API 35).
    set_target_properties(InwentaryzacjaMobile PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_COMPILE_SDK_VERSION 36
        QT_ANDROID_TARGET_SDK_VERSION 36
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_VERSION_CODE ${ANDROID_VERSION_CODE}
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
    )

    # Release signing — auto-włącz gdy keystore env-var ustawione przez build-release-aab.sh.
    # androiddeployqt korzysta z QT_ANDROID_KEYSTORE_PATH/ALIAS/STORE_PASS/KEY_PASS env-varów,
    # ale TYLKO gdy CMake zna QT_ANDROID_SIGN_AAB / QT_ANDROID_SIGN_APK = ON.
    if(DEFINED ENV{QT_ANDROID_KEYSTORE_PATH})
        message(STATUS "Android signing: enabled (keystore env detected)")
        set_target_properties(InwentaryzacjaMobile PROPERTIES
            QT_ANDROID_SIGN_AAB ON
            QT_ANDROID_SIGN_APK ON
        )
    endif()
endif()
