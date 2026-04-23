import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: "Ustawienia"
    property bool checking: false

    Connections {
        target: apiClient
        function onHealthOk(info) {
            page.checking = false
            statusLabel.text = "✓ API " + info.version + " • baza: " + info.database
                + " (" + info.exhibits_count + " eksp.)"
            statusLabel.color = "#2ecc40"
        }
        function onHealthError(msg) {
            page.checking = false
            statusLabel.text = "✗ " + msg
            statusLabel.color = "#ff4136"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

            Item { Layout.preferredHeight: 16 }

            Label {
                text: "Backend"
                font.pixelSize: 18
                font.bold: true
                Layout.leftMargin: 24
            }

            Label {
                text: "Adres URL serwera (np. http://192.168.1.100:8000)"
                opacity: 0.7
                font.pixelSize: 13
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                implicitHeight: 52
                color: "white"
                border.color: urlInput.activeFocus ? "#00bcd4" : "#888"
                border.width: urlInput.activeFocus ? 2 : 1
                radius: 6

                TextInput {
                    id: urlInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 18
                    color: "black"
                    selectByMouse: true
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                    text: appSettings.apiUrl
                    onTextChanged: appSettings.apiUrl = text
                }
                Text {
                    anchors.fill: urlInput
                    verticalAlignment: Text.AlignVCenter
                    visible: urlInput.text.length === 0
                    text: "http://…"
                    color: "#999"
                    font.pixelSize: 18
                }
            }

            Label {
                text: "Bearer token (opcjonalny — zostaw puste jeśli backend nie wymaga)"
                opacity: 0.7
                font.pixelSize: 13
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                implicitHeight: 52
                color: "white"
                border.color: tokenInput.activeFocus ? "#00bcd4" : "#888"
                border.width: tokenInput.activeFocus ? 2 : 1
                radius: 6

                TextInput {
                    id: tokenInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 18
                    color: "black"
                    selectByMouse: true
                    echoMode: TextInput.Password
                    text: appSettings.apiToken
                    onTextChanged: appSettings.apiToken = text
                }
                Text {
                    anchors.fill: tokenInput
                    verticalAlignment: Text.AlignVCenter
                    visible: tokenInput.text.length === 0
                    text: "sekretny token"
                    color: "#999"
                    font.pixelSize: 18
                }
            }

            Button {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                enabled: !page.checking
                onClicked: {
                    // Zapisz wartości przed testem (gdy user nie kliknął jeszcze w inne pole)
                    appSettings.apiUrl = urlInput.text
                    appSettings.apiToken = tokenInput.text
                    page.checking = true
                    statusLabel.text = "Sprawdzam…"
                    statusLabel.color = "white"
                    apiClient.checkHealth()
                }
                contentItem: RowLayout {
                    spacing: 6
                    BusyIndicator {
                        running: page.checking
                        visible: running
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                    }
                    Label {
                        text: page.checking ? "Sprawdzam…" : "Test połączenia"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Label {
                id: statusLabel
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                color: "white"
                wrapMode: Text.WordWrap
                font.pixelSize: 14
            }

        Item { Layout.fillHeight: true }
    }
}
