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
        function onExhibitListResult(info) {
            page.loading = false
            page.errorMsg = ""
            page.totalCount = info.total
            page.currentPage = info.page
            page.hasMore = info.has_more

            const results = info.results || []
            for (let i = 0; i < results.length; ++i) {
                const r = results[i]
                itemsModel.append({
                    exhibit_id: r.id,
                    name: r.name || "(bez nazwy)",
                    vendor: r.vendor || "",
                    model: r.model || "",
                    thumbnail_b64: r.thumbnail_b64 || ""
                })
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
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
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

            // Infinite scroll: gdy user dotrze do dolnej krawędzi, dociągamy następną stronę.
            onContentYChanged: {
                if (atYEnd && !page.loading && page.hasMore) {
                    page.loadNextPage()
                }
            }

            delegate: Rectangle {
                width: listView.width
                height: 80
                color: tap.pressed ? "#1a2a3a" : (index % 2 === 0 ? "#181818" : "#101010")

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
                            anchors.fill: parent
                            anchors.margins: 1
                            source: thumbnail_b64 !== ""
                                ? "data:image/jpeg;base64," + thumbnail_b64
                                : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: name
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: {
                                const v = vendor
                                const mo = model.model || ""  // role "model" via context
                                if (v && mo) return v + " · " + mo
                                if (v) return v
                                if (mo) return mo
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
                            exhibitId: exhibit_id,
                            initialData: {
                                name: name,
                                vendor: vendor,
                                model: model.model || "",
                                thumbnail_b64: thumbnail_b64
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
