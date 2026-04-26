pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: "Przeglądaj bazę"

    property bool loading: false
    property int currentPage: 0
    property int totalCount: 0
    property bool hasMore: true
    property string errorMsg: ""

    readonly property int pageSize: 50

    ListModel { id: itemsModel }

    Connections {
        target: apiClient
        enabled: page.StackView.status === StackView.Active
        function onExhibitListResult(info) {
            page.loading = false
            page.errorMsg = ""
            page.totalCount = info.total
            page.currentPage = info.page
            page.hasMore = info.has_more

            // Q-01: rola "device_model" zamiast "model" — unikamy kolizji z
            // delegate context keyword "model".
            // Q-D02 perf: batch append jako tablica (1 modelChanged signal vs 50).
            const mapped = (info.results || []).map(function (r) {
                return {
                    exhibit_id: r.id,
                    name: r.name || "(bez nazwy)",
                    vendor: r.vendor || "",
                    device_model: r.model || "",
                    thumbnail_b64: r.thumbnail_b64 || ""
                }
            })
            if (mapped.length > 0) {
                itemsModel.append(mapped)
            }
        }
        function onExhibitListError(msg) {
            page.loading = false
            page.errorMsg = msg
        }
    }

    function loadNextPage() {
        if (page.loading || !page.hasMore) return
        page.loading = true
        apiClient.listExhibits(page.currentPage + 1, page.pageSize)
    }

    Component.onCompleted: loadNextPage()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header bar — licznik + status
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#1a1a1a"

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 8

                Label {
                    text: page.totalCount > 0
                        ? itemsModel.count + " / " + page.totalCount
                        : (page.loading ? "Ładuję…" : "—")
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                BusyIndicator {
                    running: page.loading
                    visible: running
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
            }
        }

        // Pasek błędu (gdy backend padnie)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 40 : 0
            color: "#3a1a1a"
            visible: page.errorMsg !== ""

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Label {
                    text: "✗ " + page.errorMsg
                    color: "#ff8080"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                Button {
                    text: "Ponów"
                    onClicked: {
                        page.errorMsg = ""
                        page.loadNextPage()
                    }
                }
            }
        }

        // Lista — ListView ma własny engine scrollowania (nie wrapper Flickable),
        // więc nie wpada w landmine 1 (rainbow ScrollView bug na Fusion+Android 16).
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: itemsModel
            // Q-08: recycling delegate'ów — bez tego każdy scroll = rebuild Rectangle+RowLayout+Image+...
            reuseItems: true

            // Q-09: onAtYEndChanged zamiast per-pixel onContentYChanged
            // (firs tylko przy zmianie boolean, nie 60-120×/s podczas flicka).
            onAtYEndChanged: {
                if (atYEnd && !page.loading && page.hasMore) {
                    page.loadNextPage()
                }
            }

            delegate: Rectangle {
                id: row
                // Q-01 + Q-13: required properties zamiast implicit context — pozwala
                // na pragma ComponentBehavior: Bound i typed access.
                required property int index
                required property string exhibit_id
                required property string name
                required property string vendor
                required property string device_model
                required property string thumbnail_b64

                width: listView.width
                height: 80
                color: tap.pressed ? "#1a2a3a" : (row.index % 2 === 0 ? "#181818" : "#101010")

                // Q-08 cleanup: gdy delegate trafia do pool, anuluj load żeby zwolnić texture.
                ListView.onPooled: thumbImage.source = ""
                ListView.onReused: {
                    if (row.thumbnail_b64 !== "") {
                        thumbImage.source = "data:image/jpeg;base64," + row.thumbnail_b64
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        color: "#222"
                        radius: 4

                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            anchors.margins: 1
                            source: row.thumbnail_b64 !== ""
                                ? "data:image/jpeg;base64," + row.thumbnail_b64
                                : ""
                            // Q-06: dekoduj tylko do rozmiaru widocznego (~64dp × 2 retina)
                            // — bez tego cały JPEG idzie do RAM i GPU jako pełna textura.
                            sourceSize.width: 128
                            sourceSize.height: 128
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            // Q-10: nie krzycz, ale loguj — placeholder Rectangle pod spodem zostanie widoczny.
                            onStatusChanged: if (status === Image.Error) {
                                console.warn("[ExhibitListPage] Image.Error dla", row.exhibit_id)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: row.name
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: {
                                if (row.vendor && row.device_model) return row.vendor + " · " + row.device_model
                                if (row.vendor) return row.vendor
                                if (row.device_model) return row.device_model
                                return "—"
                            }
                            color: "#aaa"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Label {
                        text: "›"
                        color: "#666"
                        font.pixelSize: 24
                        Layout.rightMargin: 6
                    }
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    onClicked: {
                        stack.push("ExhibitDetailPage.qml", {
                            exhibitId: row.exhibit_id,
                            initialData: {
                                name: row.name,
                                vendor: row.vendor,
                                model: row.device_model,
                                thumbnail_b64: row.thumbnail_b64
                            }
                        })
                    }
                }
            }

            // Pusta lista — komunikat na środku
            Label {
                anchors.centerIn: parent
                visible: itemsModel.count === 0 && !page.loading && page.errorMsg === ""
                text: "Brak eksponatów"
                color: "#666"
                font.pixelSize: 16
            }
        }
    }
}
