import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: "Zdjęcie eksponatu"
    property string capturedPath: ""

    property bool identifying: false
    property string currentIdentifyRid: ""  // Q-05
    property string statusText: ""  // Q-11

    Connections {
        // Q-04: gate na aktywną stronę — CameraIntent jest singletonem,
        // bez tego dwie strony jednocześnie odbierałyby photoCaptured.
        target: cameraIntent
        enabled: page.StackView.status === StackView.Active
        function onPhotoCaptured(path) {
            console.log("[QML] photoCaptured:", path)
            page.capturedPath = path
            page.statusText = ""
        }
        function onPhotoError(msg) {
            console.log("[QML] photoError:", msg)
            page.statusText = msg
        }
    }

    Connections {
        target: apiClient
        enabled: page.StackView.status === StackView.Active
        function onIdentifyResult(requestId, artefakt) {
            if (requestId !== page.currentIdentifyRid) return  // Q-05
            console.log("[QML] identify OK:", JSON.stringify(artefakt))
            page.identifying = false
            page.statusText = ""
            stack.push("EditExhibitPage.qml", {
                artefakt: artefakt,
                photoPath: page.capturedPath
            })
        }
        function onIdentifyError(requestId, msg) {
            if (requestId !== page.currentIdentifyRid) return  // Q-05
            console.log("[QML] identify ERR:", msg)
            page.identifying = false
            page.statusText = "Identyfikacja: " + msg
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
                        page.statusText = "Nie mogę wczytać zdjęcia: " + source
                    }
                }
            }

            Rectangle {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 16
                }
                width: Math.min(parent.width - 32, statusLabel.implicitWidth + 32)
                height: statusLabel.implicitHeight + 16
                color: "#A0000000"
                radius: 8
                visible: page.statusText.length > 0
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    width: parent.width - 24
                    text: page.statusText  // Q-11
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
                    page.statusText = ""
                    page.capturedPath = ""
                    cameraIntent.launch()
                }
            }

            Button {
                id: identifyBtn
                Layout.fillWidth: true
                opacity: (page.capturedPath !== "" && !page.identifying) ? 1.0 : 0.4
                onClicked: {
                    if (page.capturedPath === "" || page.identifying) return
                    page.identifying = true
                    page.statusText = "Wysyłam do AI…"
                    page.currentIdentifyRid = apiClient.identify(page.capturedPath)  // Q-05
                }
                contentItem: RowLayout {
                    spacing: 6
                    BusyIndicator {
                        running: page.identifying
                        visible: running
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                    }
                    Label {
                        text: page.identifying ? "Identyfikuję…" : "Zidentyfikuj"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        // Automatyczne odpalenie kamery przy wejściu na ekran — UX jak w natywnej apce
        cameraIntent.launch()
    }
}
