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
                text: stack.currentPage?.title ?? "Inwentaryzacja"  // Q-02
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
                    if (stack.currentPage?.title === "Ustawienia") return  // Q-02
                    stack.push("SettingsPage.qml")
                }
            }
        }
    }

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: welcomePage
        // Q-02: type narrowing — stack.currentItem to QQuickItem (any), reach
        // do .title bez kastu daje 'undefined' przy pustym stosie.
        readonly property Page currentPage: stack.currentItem as Page
    }

    // C-D09 wariant A: globalny handler 401 — gdy ApiClient odrzuci token,
    // pokaz toast i auto-nawiguj do Ustawien (chyba ze user juz tam jest).
    // Token na Androidzie jest sessional (security tier-1.5), wiec po restart
    // user MUSI go wpisac ponownie — bez tego sygnalu nie wie gdzie isc.
    Connections {
        target: apiClient
        function onTokenRequired() {
            tokenSnackbar.show()
            if (stack.currentPage?.title !== "Ustawienia") {  // Q-02
                stack.push("SettingsPage.qml")
            }
        }
    }

    Rectangle {
        id: tokenSnackbar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32 + SafeArea.margins.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 32, 360)
        height: 56
        radius: 8
        color: "#cc0033"
        opacity: 0
        z: 1000
        function show() {
            opacity = 1
            hideTimer.restart()
        }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Label {
            anchors.centerIn: parent
            text: "Token niepoprawny — wpisz ponownie w Ustawieniach"
            color: "white"
            font.pixelSize: 14
            font.bold: true
        }
        Timer {
            id: hideTimer
            interval: 3500
            onTriggered: tokenSnackbar.opacity = 0
        }
    }

    Component {
        id: welcomePage
        Page {
            id: welcomeRoot
            title: "Inwentaryzacja"
            // Q-05: filtruj sygnaly per requestId — bez tego stara odpowiedz health
            // (np. od starego URL przed zmiana w Settings) trafilaby tu i nadpisala
            // backendInfo z nowego sprawdzenia.
            property string currentHealthRid: ""
            // Q-14: backendInfo trzymamy jako var ale wystawiamy derived stringi.
            property var backendInfo: null
            readonly property string version: backendInfo?.version ?? "?"
            readonly property string database: backendInfo?.database ?? "?"
            readonly property int exhibitsCount: backendInfo?.exhibits_count ?? 0
            readonly property int clipIndexSize: backendInfo?.clip_index_size ?? 0
            readonly property bool mockIdentify: backendInfo?.mock_identify ?? false
            property string backendError: ""
            property bool loading: true

            Connections {
                target: apiClient
                function onHealthOk(requestId, info) {
                    if (requestId !== welcomeRoot.currentHealthRid) return  // Q-05
                    welcomeRoot.backendInfo = info
                    welcomeRoot.backendError = ""
                    welcomeRoot.loading = false
                }
                function onHealthError(requestId, msg) {
                    if (requestId !== welcomeRoot.currentHealthRid) return  // Q-05
                    welcomeRoot.backendInfo = null
                    welcomeRoot.backendError = msg
                    welcomeRoot.loading = false
                }
            }

            Component.onCompleted: welcomeRoot.currentHealthRid = apiClient.checkHealth()

            // Auto-refresh co 15s gdy Welcome jest widoczny
            Timer {
                interval: 15000
                running: stack.currentItem === welcomeRoot
                repeat: true
                onTriggered: welcomeRoot.currentHealthRid = apiClient.checkHealth()
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
                            welcomeRoot.currentHealthRid = apiClient.checkHealth()  // Q-05
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
                                        : "✓ Backend OK (v" + welcomeRoot.version + ")")
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
                                : "Baza: " + welcomeRoot.database
                                  + " • " + welcomeRoot.exhibitsCount + " eksp."
                            color: "#ccc"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            visible: !welcomeRoot.loading
                        }

                        Label {
                            text: "CLIP index: " + welcomeRoot.clipIndexSize
                                + (welcomeRoot.mockIdentify ? "  •  ⚙ MOCK AI" : "")
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

                Button {
                    text: "Przeglądaj bazę"
                    Layout.fillWidth: true
                    enabled: !welcomeRoot.backendError
                    opacity: welcomeRoot.backendError ? 0.5 : 1.0
                    onClicked: stack.push("ExhibitListPage.qml")
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
