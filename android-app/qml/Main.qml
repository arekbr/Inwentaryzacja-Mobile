import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 400
    height: 700
    title: "Inwentaryzacja"

    Material.theme: Material.Dark
    Material.accent: Material.Teal

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            Label {
                text: "Inwentaryzacja"
                font.pixelSize: 20
                font.bold: true
                Layout.leftMargin: 16
                Layout.fillWidth: true
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        Item { Layout.fillHeight: true }

        Label {
            text: "Witaj!"
            font.pixelSize: 32
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Mobilna wersja katalogu\nmuzeum retro-computingu"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 16
            opacity: 0.7
            Layout.alignment: Qt.AlignHCenter
        }

        Item { Layout.preferredHeight: 20 }

        Button {
            text: "Zrób zdjęcie eksponatu"
            Layout.fillWidth: true
            highlighted: true
            enabled: false
            onClicked: console.log("TODO: camera")
        }

        Button {
            text: "Znajdź podobne"
            Layout.fillWidth: true
            enabled: false
            onClicked: console.log("TODO: similar")
        }

        Label {
            text: "Środowisko: " + Qt.platform.os
            font.pixelSize: 12
            opacity: 0.5
            Layout.alignment: Qt.AlignHCenter
        }

        Item { Layout.fillHeight: true }
    }
}
