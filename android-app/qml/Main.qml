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
        RowLayout {
            anchors.fill: parent
            ToolButton {
                text: "‹"
                font.pixelSize: 28
                visible: stack.depth > 1
                onClicked: stack.pop()
            }
            Label {
                text: stack.currentItem ? (stack.currentItem.title || "Inwentaryzacja") : "Inwentaryzacja"
                font.pixelSize: 20
                font.bold: true
                Layout.leftMargin: stack.depth > 1 ? 0 : 16
                Layout.fillWidth: true
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
