pragma Singleton
import QtQuick 2.0
import org.duckdns.jgressmann 1.0

Item {
    readonly property var filterKeys:["game", "tournament", "year"]
    readonly property int gridItemsPerPage: 8

    function whereClause(filters) {
        var where = ""
        if (typeof(filters) === "object") {
            for (var key in filters) {
                var skey = sanitize(key.toString())
                var value = sanitize(filters[key].toString())
                if (where.length > 0) {
                    where += " and "
                } else {
                    where += " where "
                }

                where += skey + "='" + value + "'"
            }
        }

        return where;
    }

    function sanitize(str) {
        str = _replaceWhileChange(str, "\\", "")
        str = _replaceWhileChange(str, ";", "")
        str = _replaceWhileChange(str, "'", "\\'")
        str = _replaceWhileChange(str, "\"", "\\\"")
//        var index = str.indexOf(" ")
//        if (index >= 0) {
//            str = "\"" + str + "\""
//        }

        return str
    }

    function _replaceWhileChange(str, needle, replacement) {
        var index = str.indexOf(needle)
        if (index >= 0) {
            var x = str;
            do {
                str = x;
                x = str.replace(needle, replacement)
            } while (x !== str)
        }

        return str
    }

    function rowCount(filters) {
        var where = whereClause(filters)
        var uniqueTuples = "select distinct " + filterKeys.join(",") + " from vods" + where
        var sql = "select count(*) as count from (" + uniqueTuples  + ")"
        console.debug(sql)


        _model.select = sql;
        if (_model.rowCount() !== 1) {
            var error = _model.lastError
            console.debug("sql error: " + error)
            return
        }

        var result = _model.data(_model.index(0, 0), 0)
        console.debug("sql result: " + result)
        return result
    }

    function clone(obj) {
        if (null == obj || "object" != typeof obj) return obj;
        var copy = obj.constructor();
        for (var attr in obj) {
            if (obj.hasOwnProperty(attr)) copy[attr] = clone(obj[attr]);
        }
        return copy;
    }

    function merge(dict1, dict2) {
        var result = {}
        for (var key in dict1) {
            result[key] = dict1[key]
        }

        for (var key in dict2) {
            result[key] = dict2[key]
        }

        return result
    }



    SqlVodModel {
        id: _model
        columns: ["count"]
        vodModel: Sc2LinksDotCom
    }


}
