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
            id: welcomeRoot
            title: "Inwentaryzacja"
            property var backendInfo: ({})
            property string backendError: ""
            property bool loading: true

            Connections {
                target: apiClient
                function onHealthOk(info) {
                    welcomeRoot.backendInfo = info
                    welcomeRoot.backendError = ""
                    welcomeRoot.loading = false
                }
                function onHealthError(msg) {
                    welcomeRoot.backendInfo = ({})
                    welcomeRoot.backendError = msg
                    welcomeRoot.loading = false
                }
            }

            Component.onCompleted: apiClient.checkHealth()

            // Auto-refresh co 15s gdy Welcome jest widoczny
            Timer {
                interval: 15000
                running: stack.currentItem === welcomeRoot
                repeat: true
                onTriggered: apiClient.checkHealth()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Item { Layout.preferredHeight: 8 }

                Label {
                    text: "Witaj!"
                    font.pixelSize: 30
                    font.bold: true
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    text: "Mobilna wersja katalogu\nmuzeum retro-computingu"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 14
                    color: "#aaa"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Panel statusu backendu — tap żeby odświeżyć
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: statusCol.implicitHeight + 20
                    color: refreshTap.pressed
                        ? (welcomeRoot.backendError ? "#4a2a2a" : "#2a4a3a")
                        : (welcomeRoot.backendError ? "#3a1a1a" : "#1a3a2a")
                    radius: 6
                    border.color: welcomeRoot.backendError ? "#ff4136" : "#2ecc40"
                    border.width: 1

                    MouseArea {
                        id: refreshTap
                        anchors.fill: parent
                        enabled: !welcomeRoot.loading
                        onClicked: {
                            welcomeRoot.loading = true
                            apiClient.checkHealth()
                        }
                    }

                    ColumnLayout {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            BusyIndicator {
                                running: welcomeRoot.loading
                                visible: running
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                            }
                            Label {
                                text: welcomeRoot.loading ? "Sprawdzam backend…"
                                    : (welcomeRoot.backendError
                                        ? "✗ Backend offline"
                                        : "✓ Backend OK (v" + welcomeRoot.backendInfo.version + ")")
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Label {
                            text: welcomeRoot.backendError
                                ? welcomeRoot.backendError
                                : "Baza: " + (welcomeRoot.backendInfo.database || "?")
                                  + " • " + (welcomeRoot.backendInfo.exhibits_count || 0) + " eksp."
                            color: "#ccc"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            visible: !welcomeRoot.loading
                        }

                        Label {
                            text: "CLIP index: " + (welcomeRoot.backendInfo.clip_index_size || 0)
                                + (welcomeRoot.backendInfo.mock_identify ? "  •  ⚙ MOCK AI" : "")
                            color: "#999"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            visible: !welcomeRoot.loading && !welcomeRoot.backendError
                        }
                    }
                }

                Button {
                    text: "Zrób zdjęcie eksponatu"
                    Layout.fillWidth: true
                    highlighted: true
                    enabled: !welcomeRoot.backendError
                    opacity: welcomeRoot.backendError ? 0.5 : 1.0
                    onClicked: stack.push("CameraPage.qml")
                }

                Button {
                    text: "Znajdź podobne"
                    Layout.fillWidth: true
                    enabled: !welcomeRoot.backendError
                    opacity: welcomeRoot.backendError ? 0.5 : 1.0
                    onClicked: stack.push("SimilarPage.qml")
                }

                Item { Layout.fillHeight: true }

                Label {
                    text: "Środowisko: " + Qt.platform.os
                    font.pixelSize: 11
                    color: "#666"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
