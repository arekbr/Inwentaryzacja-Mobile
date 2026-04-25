import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: "Edycja eksponatu"

    // Ustawiane przez StackView.push(..., {artefakt, photoPath})
    property var artefakt: ({})
    property string photoPath: ""
    property bool saving: false

    property string fName: artefakt.name || ""
    property string fType: artefakt.type || "Inne"
    property string fVendor: artefakt.vendor || ""
    property string fModel: artefakt.model || ""
    property string fSerial: artefakt.serial_number || ""
    property string fPart: artefakt.part_number || ""
    property string fRevision: artefakt.revision || ""
    property string fYear: artefakt.production_year ? String(artefakt.production_year) : ""
    property string fStatus: artefakt.status || "Niesprawdzony"
    property string fStorage: "Dom"
    property string fDescription: artefakt.description || ""
    property bool fPacking: artefakt.has_original_packaging || false

    Connections {
        target: apiClient
        function onExhibitSaved(id, photosCount) {
            page.saving = false
            statusLabel.text = "✓ Zapisano (id: " + id.substr(0, 8) + "…)"
            statusLabel.color = "#2ecc40"
            returnTimer.start()
        }
        function onExhibitError(msg) {
            page.saving = false
            statusLabel.text = "✗ " + msg
            statusLabel.color = "#ff4136"
        }
    }

    Timer {
        id: returnTimer
        interval: 1500
        // Q-05: pop(page) zamiast pop(null) — gdy timer wystrzeli z opóźnieniem
        // a user już nawigował dalej, pop(null) cofnie do root i wywali jego stronę.
        // pop(page) cofnie tylko jeśli `page` jest na stosie.
        onTriggered: stack.pop(page)
    }

    // Komponent "wiersz" — Label | Input obok siebie (żeby zmieścić bez scrolla)
    component FormRow: RowLayout {
        property alias label: labelItem.text
        property alias value: inputItem.text
        property alias inputId: inputItem
        property var hints: 0
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        spacing: 8
        Label {
            id: labelItem
            color: "white"
            opacity: 0.85
            font.pixelSize: 13
            Layout.preferredWidth: 90
            wrapMode: Text.WordWrap
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            color: "white"
            radius: 5
            border.color: inputItem.activeFocus ? "#00bcd4" : "#666"
            border.width: inputItem.activeFocus ? 2 : 1
            TextInput {
                id: inputItem
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 15
                color: "black"
                selectByMouse: true
                inputMethodHints: parent.parent.hints || Qt.ImhNone
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        // Q-15: IME-aware bottom margin — bez tego soft keyboard zakrywa Save button.
        // Animowane przez Behavior żeby uniknąć skoków przy pojawieniu/zniknięciu klawiatury.
        anchors.bottomMargin: Qt.inputMethod.visible
            ? Math.max(0, Qt.inputMethod.keyboardRectangle.height - SafeArea.margins.bottom)
            : 0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 150 } }
        spacing: 8

        Item { Layout.preferredHeight: 4 }

        // Zdjęcie
        Image {
            id: photoImage
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 180
            source: page.photoPath !== "" ? "file://" + page.photoPath : ""
            // Q-06: cap dekodowania (180dp × 2 retina)
            sourceSize.height: 360
            fillMode: Image.PreserveAspectFit
            autoTransform: true
            asynchronous: true
            // Q-10: gdy Android wyrzuci cache między capture a edit
            onStatusChanged: if (status === Image.Error) {
                console.warn("[EditExhibitPage] Image.Error:", photoImage.source)
                statusLabel.text = "✗ Nie mogę wczytać zdjęcia (cache cleanup?)"
                statusLabel.color = "#ff4136"
            }
        }

        // AI pewność
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 32
            color: "#1a3a5c"
            radius: 5
            Label {
                anchors.fill: parent
                anchors.leftMargin: 8
                text: "AI: pewność " + (artefakt.analiza ? artefakt.analiza.pewnosc : "?")
                      + (artefakt.analiza && artefakt.analiza.wymaga_weryfikacji ? " — wymaga weryfikacji" : "")
                color: "white"
                font.pixelSize: 12
                font.bold: true
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }

        FormRow { label: "Nazwa";     value: page.fName;    inputId.onTextChanged: page.fName = text }
        FormRow { label: "Typ";       value: page.fType;    inputId.onTextChanged: page.fType = text }
        FormRow { label: "Producent"; value: page.fVendor;  inputId.onTextChanged: page.fVendor = text }
        FormRow { label: "Model";     value: page.fModel;   inputId.onTextChanged: page.fModel = text }
        FormRow { label: "Nr seryjny";value: page.fSerial;  inputId.onTextChanged: page.fSerial = text }
        FormRow { label: "Rok prod.";  value: page.fYear;    hints: Qt.ImhDigitsOnly; inputId.onTextChanged: page.fYear = text }
        FormRow { label: "Status";    value: page.fStatus;  inputId.onTextChanged: page.fStatus = text }
        FormRow { label: "Miejsce";   value: page.fStorage; inputId.onTextChanged: page.fStorage = text }

        // Opakowanie — checkbox+label w wierszu (compact)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8
            Rectangle {
                implicitWidth: 24; implicitHeight: 24
                color: page.fPacking ? "#00bcd4" : "white"
                border.color: "#666"; border.width: 1; radius: 4
                Label {
                    anchors.centerIn: parent
                    text: "✓"; color: "white"; font.pixelSize: 16; font.bold: true
                    visible: page.fPacking
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: page.fPacking = !page.fPacking
                }
            }
            Label {
                text: "Oryginalne opakowanie"
                color: "white"; font.pixelSize: 13
                Layout.fillWidth: true
            }
        }

        // Zapisz
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            Layout.preferredHeight: 48
            color: page.saving ? "#555" : "#2ecc40"
            radius: 5
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                BusyIndicator {
                    running: page.saving
                    visible: running
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                }
                Label {
                    text: page.saving ? "Zapisuję…" : "Zapisz do bazy"
                    color: "white"; font.pixelSize: 15; font.bold: true
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !page.saving
                onClicked: {
                    if (!page.fName || !page.fVendor || !page.fModel) {
                        statusLabel.text = "Wymagane: nazwa, producent, model"
                        statusLabel.color = "#ff4136"
                        return
                    }
                    page.saving = true
                    statusLabel.text = "Wysyłam do bazy…"
                    statusLabel.color = "white"
                    const payload = {
                        name: page.fName, type: page.fType, vendor: page.fVendor, model: page.fModel,
                        serial_number: page.fSerial || null, part_number: page.fPart || null, revision: page.fRevision || null,
                        production_year: page.fYear ? parseInt(page.fYear, 10) : null,
                        status: page.fStatus, storage_place: page.fStorage,
                        description: page.fDescription, has_original_packaging: page.fPacking
                    }
                    apiClient.saveExhibit(payload, page.photoPath)
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

        Item { Layout.fillHeight: true }
    }
}
