import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: "Szczegóły eksponatu"

    // Ustawiane przez StackView.push(..., {exhibitId, initialData})
    property string exhibitId: ""
    property var initialData: ({})       // opcjonalne minimum z listy similarity (name, vendor, model, thumbnail_b64)
    property var detail: ({})            // pełny rekord pobrany z /api/v1/exhibits/{id}
    property bool loading: true
    property string errorMsg: ""

    Connections {
        target: apiClient
        function onExhibitDetail(d) {
            if (d.id === page.exhibitId) {
                page.detail = d
                page.loading = false
            }
        }
        function onExhibitDetailError(msg) {
            page.errorMsg = msg
            page.loading = false
        }
    }

    Component.onCompleted: {
        if (exhibitId) {
            apiClient.getExhibit(exhibitId)
        } else {
            errorMsg = "Brak exhibit_id"
            loading = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Zdjęcie (duże — detail_b64 z backendu, ~800px; fallback: initialData.thumbnail_b64)
        Image {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 260
            source: page.detail.photo_b64
                ? "data:image/jpeg;base64," + page.detail.photo_b64
                : (page.initialData.thumbnail_b64
                    ? "data:image/jpeg;base64," + page.initialData.thumbnail_b64
                    : "")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
        }

        // Loading / error
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            visible: page.loading || page.errorMsg.length > 0
            spacing: 8
            BusyIndicator {
                running: page.loading
                visible: running
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }
            Label {
                text: page.loading ? "Pobieram szczegóły…" : ("✗ " + page.errorMsg)
                color: page.errorMsg.length > 0 ? "#ff4136" : "white"
                font.pixelSize: 13
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        // Tytuł + producent/model
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            text: page.detail.name || page.initialData.name || "(ładuję…)"
            color: "white"; font.pixelSize: 18; font.bold: true
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            text: [page.detail.vendor || page.initialData.vendor,
                   page.detail.model || page.initialData.model].filter(x => x).join(" ")
            color: "#aaa"; font.pixelSize: 14
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }

        // Kluczowe pola — compact 2-column grid: label | value
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            columns: 2
            columnSpacing: 12
            rowSpacing: 4

            // Każde pole pokazuje się tylko gdy ma wartość (visible: text !== "")
            Label { text: "Typ"; color: "#888"; font.pixelSize: 12; visible: typeValue.visible }
            Label { id: typeValue; text: page.detail.type || ""; color: "white"; font.pixelSize: 13; Layout.fillWidth: true; visible: text.length > 0 }

            Label { text: "Rok"; color: "#888"; font.pixelSize: 12; visible: yearValue.visible }
            Label { id: yearValue; text: page.detail.production_year ? String(page.detail.production_year) : ""; color: "white"; font.pixelSize: 13; Layout.fillWidth: true; visible: text.length > 0 }

            Label { text: "Status"; color: "#888"; font.pixelSize: 12; visible: statusValue.visible }
            Label { id: statusValue; text: page.detail.status || ""; color: "white"; font.pixelSize: 13; Layout.fillWidth: true; visible: text.length > 0 }

            Label { text: "Miejsce"; color: "#888"; font.pixelSize: 12; visible: storageValue.visible }
            Label { id: storageValue; text: page.detail.storage_place || ""; color: "white"; font.pixelSize: 13; Layout.fillWidth: true; visible: text.length > 0 }

            Label { text: "Serial"; color: "#888"; font.pixelSize: 12; visible: serialValue.visible }
            Label { id: serialValue; text: page.detail.serial_number || ""; color: "white"; font.pixelSize: 13; Layout.fillWidth: true; visible: text.length > 0 }
        }

        // Opis — skrócony do ~200 znaków (pełny na desktopie, mobile ma glance view)
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            Layout.topMargin: 4
            text: {
                const d = page.detail.description || ""
                if (!d) return ""
                return d.length > 220 ? d.substring(0, 220) + "…" : d
            }
            color: "#ccc"; font.pixelSize: 12
            wrapMode: Text.WordWrap
            visible: text.length > 0
        }

        Item { Layout.fillHeight: true }
    }
}
