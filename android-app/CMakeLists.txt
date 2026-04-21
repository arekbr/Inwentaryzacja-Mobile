cmake_minimum_required(VERSION 3.21)

project(InwentaryzacjaMobile
    VERSION 0.1.0
    DESCRIPTION "Mobilna apka Qt Android — katalogowanie eksponatów muzeum"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network Multimedia)

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
)

target_link_libraries(InwentaryzacjaMobile PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::Multimedia
)

# === Android-specific ===
if(ANDROID)
    set_target_properties(InwentaryzacjaMobile PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_TARGET_SDK_VERSION 35
        QT_ANDROID_MIN_SDK_VERSION 26
        QT_ANDROID_VERSION_CODE 1
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
    )
endif()
