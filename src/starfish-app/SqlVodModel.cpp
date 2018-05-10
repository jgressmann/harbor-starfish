/* The MIT License (MIT)
 *
 * Copyright (c) 2018 Jean Gressmann <jean@0x42.de>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "SqlVodModel.h"
#include "ScVodDataManager.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QDebug>


// https://wiki.qt.io/How_to_Use_a_QSqlQueryModel_in_QML

SqlVodModel::~SqlVodModel() {

}

SqlVodModel::SqlVodModel(QObject* parent)
    : QSqlQueryModel(parent)
{
    m_DataManager = Q_NULLPTR;
    m_Dirty = false;
}

QVariant
SqlVodModel::data(const QModelIndex &modelIndex, int role) const {
    if (role < Qt::UserRole) {
        return QSqlQueryModel::data(modelIndex, role);
    }

    int column = role - Qt::UserRole - 1;
    QModelIndex remappedIndex = index(modelIndex.row(), column);
    return QSqlQueryModel::data(remappedIndex, Qt::DisplayRole);
}

QHash<int,QByteArray>
SqlVodModel::roleNames() const {
    return m_RoleNames;
}

QString
SqlVodModel::select() const {
    return m_Select;
}

void
SqlVodModel::setSelect(QString newValue) {
    if (m_Select != newValue) {
        m_Select = newValue;
        emit selectChanged();
        m_Dirty = true;
        update();
    }
}

ScVodDataManager*
SqlVodModel::dataManager() const {
    return m_DataManager;
}

void
SqlVodModel::setDataManager(ScVodDataManager* newValue) {
    if (newValue != m_DataManager) {
        m_Dirty = true;

        if (m_DataManager) {
            disconnect(m_DataManager, &ScVodDataManager::vodsChanged,
                       this,  &SqlVodModel::update);
        }

        m_DataManager = newValue;
        emit dataManagerChanged();

        if (m_DataManager) {
            connect(m_DataManager, &ScVodDataManager::vodsChanged,
                       this,  &SqlVodModel::update);
            update();
        }
    }
}



void
SqlVodModel::update() {
    if (m_Dirty) {
        m_Dirty = !tryConfigureModel();
    } else {
        setQuery(m_Select, m_DataManager->database());
    }
}

bool
SqlVodModel::tryConfigureModel() {
    if (m_DataManager &&
       !m_Select.isEmpty() &&
       !m_Columns.empty()) {

        setQuery(m_Select, m_DataManager->database());
        beginResetModel();
        for (int i = 0; i < m_Columns.count(); ++i) {
            setHeaderData(0, Qt::Horizontal, m_Columns[i]);
        }
        endResetModel();
//        refresh();

        return true;
    }

    return false;
}

void
SqlVodModel::refresh() {
    beginResetModel();
    setQuery(m_Select, m_DataManager->database());
    for (int i = 0; i < m_Columns.count(); ++i) {
        setHeaderData(0, Qt::Horizontal, m_Columns[i]);
    }
    endResetModel();
}

QStringList
SqlVodModel::columns() const {
    return m_Columns;
}

void
SqlVodModel::setColumns(const QStringList& newValue) {
    m_Dirty = true;
    m_Columns = newValue;
    m_RoleNames.clear();
    for (int i = 0; i < m_Columns.count(); ++i) {
        m_RoleNames[Qt::UserRole + i + 1] = m_Columns[i].toLocal8Bit();
    }
    emit columnsChanged();
    update();
}
