import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: "Zdjęcie eksponatu"
    property string capturedPath: ""

    Connections {
        target: cameraIntent
        function onPhotoCaptured(path) {
            console.log("[QML] photoCaptured:", path)
            page.capturedPath = path
            statusLabel.text = ""
        }
        function onPhotoError(msg) {
            console.log("[QML] photoError:", msg)
            statusLabel.text = msg
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#101010"

            // Placeholder gdy brak zdjęcia
            ColumnLayout {
                anchors.centerIn: parent
                visible: page.capturedPath === ""
                spacing: 12

                Label {
                    text: "📷"
                    font.pixelSize: 96
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: "Naciśnij „Zrób zdjęcie” by uruchomić\naparat Pixela (HDR+, Night Sight)"
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Image {
                id: previewImg
                anchors.fill: parent
                anchors.margins: 4
                visible: page.capturedPath !== ""
                source: page.capturedPath !== "" ? "file://" + page.capturedPath : ""
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: true
                autoTransform: true  // respektuj EXIF Orientation (Pixel zapisuje foto z tagiem)
                onStatusChanged: {
                    console.log("[QML] previewImg status:", status, "src:", source)
                    if (status === Image.Error) {
                        statusLabel.text = "Nie mogę wczytać zdjęcia: " + source
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 16
                width: Math.min(parent.width - 32, statusLabel.implicitWidth + 32)
                height: statusLabel.implicitHeight + 16
                color: "#A0000000"
                radius: 8
                visible: statusLabel.text.length > 0
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    width: parent.width - 24
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 16

            Button {
                text: page.capturedPath === "" ? "Zrób zdjęcie" : "Zrób ponownie"
                Layout.fillWidth: true
                onClicked: {
                    statusLabel.text = ""
                    page.capturedPath = ""
                    cameraIntent.launch()
                }
            }

            Button {
                text: "Użyj"
                Layout.fillWidth: true
                opacity: page.capturedPath !== "" ? 1.0 : 0.4
                onClicked: {
                    if (page.capturedPath === "") return
                    console.log("Accept photo:", page.capturedPath)
                    statusLabel.text = "Następny krok: /identify (TODO)"
                }
            }
        }
    }

    Component.onCompleted: {
        // Automatyczne odpalenie kamery przy wejściu na ekran — UX jak w natywnej apce
        cameraIntent.launch()
    }
}
