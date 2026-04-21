import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 400
    height: 700
    title: "Inwentaryzacja"

    header: ToolBar {
        id: topBar
        // Android 15+ edge-to-edge — status bar nachodzi na apkę, SafeArea.margins.top
        // zwraca 0 w Basic/Fusion. Hardcoded 60 dla statusu + notch Pixel 10 Pro.
        topPadding: Math.max(SafeArea.margins.top, 60)
        leftPadding: Math.max(SafeArea.margins.left, 8)
        rightPadding: Math.max(SafeArea.margins.right, 8)
        bottomPadding: 4

        background: Rectangle { color: "#1a1a1a" }

        RowLayout {
            anchors.fill: parent
            spacing: 4

            ToolButton {
                text: "‹"
                font.pixelSize: 32
                implicitWidth: 56
                implicitHeight: 56
                visible: stack.depth > 1
                onClicked: stack.pop()
            }
            Label {
                text: stack.currentItem ? (stack.currentItem.title || "Inwentaryzacja") : "Inwentaryzacja"
                font.pixelSize: 20
                font.bold: true
                color: "white"
                verticalAlignment: Text.AlignVCenter
                Layout.leftMargin: stack.depth > 1 ? 0 : 12
                Layout.fillWidth: true
            }
            ToolButton {
                text: "⚙"
                font.pixelSize: 24
                implicitWidth: 56
                implicitHeight: 56
                onClicked: {
                    if (stack.currentItem && stack.currentItem.title === "Ustawienia") return
                    stack.push("SettingsPage.qml")
                }
            }
        }
    }

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: welcomePage
    }

    Component {
        id: welcomePage
        Page {
            title: "Inwentaryzacja"

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
                    onClicked: stack.push("CameraPage.qml")
                }

                Button {
                    text: "Znajdź podobne (wkrótce)"
                    Layout.fillWidth: true
                    opacity: 0.4
                    onClicked: {}
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
    }
}
