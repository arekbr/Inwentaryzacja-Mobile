import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: "Znajdź podobne"

    property string capturedPath: ""
    property bool searching: false
    property var results: []
    property int indexSize: 0

    Connections {
        target: cameraIntent
        function onPhotoCaptured(path) {
            page.capturedPath = path
            statusLabel.text = ""
        }
        function onPhotoError(msg) {
            statusLabel.text = msg
        }
    }

    Connections {
        target: apiClient
        function onSimilarResult(list, size) {
            page.searching = false
            page.results = list
            page.indexSize = size
            statusLabel.text = list.length === 0
                ? "Brak wyników (index: " + size + ")"
                : "Znaleziono " + list.length + " z " + size
        }
        function onSimilarError(msg) {
            page.searching = false
            page.results = []
            statusLabel.text = "✗ " + msg
            statusLabel.color = "#ff4136"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Foto (kompakt, 120dp żeby zostawić miejsce na 5 wyników)
        Image {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 120
            source: page.capturedPath !== "" ? "file://" + page.capturedPath : ""
            fillMode: Image.PreserveAspectFit
            autoTransform: true
            asynchronous: true
            cache: false
        }

        // Button Szukaj (lub "Zrób ponownie" gdy już jest foto)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                color: "#555"
                radius: 5
                Label {
                    anchors.centerIn: parent
                    text: page.capturedPath === "" ? "Zrób zdjęcie" : "Zrób ponownie"
                    color: "white"; font.pixelSize: 14; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        page.capturedPath = ""
                        page.results = []
                        statusLabel.text = ""
                        cameraIntent.launch()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                color: (page.capturedPath !== "" && !page.searching) ? "#00bcd4" : "#333"
                radius: 5
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    BusyIndicator {
                        running: page.searching
                        visible: running
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                    }
                    Label {
                        text: page.searching ? "Szukam…" : "Szukaj podobnych"
                        color: "white"; font.pixelSize: 14; font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: page.capturedPath !== "" && !page.searching
                    onClicked: {
                        page.searching = true
                        statusLabel.text = "CLIP embedding + LanceDB search…"
                        statusLabel.color = "white"
                        apiClient.findSimilar(page.capturedPath, 5)
                    }
                }
            }
        }

        Label {
            id: statusLabel
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            color: "white"; font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        // 5 wyników — Repeater. Każdy wiersz w Rectangle z MouseArea → tap → detail view.
        Repeater {
            model: page.results
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.preferredHeight: 80
                color: tapArea.pressed ? "#1a2a3a" : "transparent"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 10

                    Image {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        source: modelData.thumbnail_b64
                            ? "data:image/jpeg;base64," + modelData.thumbnail_b64
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: modelData.name || "(bez nazwy)"
                            color: "white"; font.pixelSize: 14; font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: (modelData.vendor || "") + (modelData.model ? " " + modelData.model : "")
                            color: "#aaa"; font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: "dystans: " + (modelData.distance !== undefined
                                ? modelData.distance.toFixed(3) : "?")
                            color: "#888"; font.pixelSize: 11
                        }
                    }

                    Label {
                        text: "›"
                        color: "#666"; font.pixelSize: 24
                        Layout.rightMargin: 6
                    }
                }

                MouseArea {
                    id: tapArea
                    anchors.fill: parent
                    onClicked: {
                        stack.push("ExhibitDetailPage.qml", {
                            exhibitId: modelData.exhibit_id,
                            initialData: modelData
                        })
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    Component.onCompleted: {
        // Auto-odpal kamerę przy wejściu (UX jak na CameraPage)
        cameraIntent.launch()
    }
}
