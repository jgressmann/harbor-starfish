import QtQuick 2.0
import Sailfish.Silica 1.0
import org.duckdns.jgressmann 1.0
import ".."

Page {
    id: page

    property string title: undefined
    property var filters: undefined
    property string key: undefined
    property bool ascending: true
    property bool grid: false

    SqlVodModel {
        id: sqlModel
        vodModel: Sc2LinksDotCom
        columns: [key]
        select: {
            var sql = "select distinct "+ key +" from vods"
            sql += Global.whereClause(filters)
            sql += " order by " + key + " " + (ascending ? "asc" : "desc")
            console.debug(title + ": " + sql)
            return sql
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        // Why is this necessary?
        contentWidth: parent.width


        VerticalScrollDecorator {}

        SilicaListView {
            id: listView
            anchors.fill: parent
            model: sqlModel
            visible: !grid
            header: PageHeader {
                title: page.title
            }

            delegate: FilteredItem {
                width: listView.width
                key: page.key
                value: sqlModel.data(sqlModel.index(index, 0), 0)
                filters: page.filters
                grid: page.grid

                Component.onCompleted: {
                    console.debug("filter page key: "+key+" index: " + index + " value: " + value)
                }
            }

            ViewPlaceholder {
                enabled: listView.count === 0
                text: "nothing here"
            }
        }

        SilicaGridView {
            id: gridView
            anchors.fill: parent
            model: sqlModel
            visible: grid
            header: PageHeader {
                title: page.title
            }

            cellWidth: width / 2;
            cellHeight: height / (Global.gridItemsPerPage / 2)

            delegate: FilteredItem {
                key: page.key
                value: sqlModel.data(sqlModel.index(index, 0), 0)
                filters: page.filters
                grid: page.grid
                height: gridView.cellHeight
                width: gridView.cellWidth

                Component.onCompleted: {
                    console.debug("filter page key: "+key+" index: " + index + " value: " + value)
                }
            }

            ViewPlaceholder {
                enabled: gridView.count === 0
                text: "nothing here"
            }
        }
    }
}

