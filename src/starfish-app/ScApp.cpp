/* The MIT License (MIT)
 *
 * Copyright (c) 2018, 2019 Jean Gressmann <jean@0x42.de>
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

#include "ScApp.h"

#include <QNetworkConfiguration>
#include <QUrl>
#include <QStandardPaths>
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QTemporaryFile>



ScApp::ScApp(QObject* parent)
    : QObject(parent)
{
    connect(&m_NetworkConfigurationManager, &QNetworkConfigurationManager::onlineStateChanged, this, &ScApp::onOnlineStateChanged);
}

QString
ScApp::version() const {
    return QStringLiteral("%1.%2.%3").arg(QString::number(STARFISH_VERSION_MAJOR), QString::number(STARFISH_VERSION_MINOR), QString::number(STARFISH_VERSION_PATCH));
}

QString
ScApp::displayName() const {
    return QStringLiteral("Starfish");
}

bool
ScApp::isOnBroadband() const {
    auto configs = m_NetworkConfigurationManager.allConfigurations(QNetworkConfiguration::Active);
    foreach (const auto& config, configs) {
        if (config.isValid()) {
            switch (config.bearerTypeFamily()) {
            case QNetworkConfiguration::BearerEthernet:
            case QNetworkConfiguration::BearerWLAN:
                return true;
            default:
                break;
            }
        }
    }

    return false;
}

bool
ScApp::isOnMobile() const {
    auto configs = m_NetworkConfigurationManager.allConfigurations(QNetworkConfiguration::Active);
    foreach (const auto& config, configs) {
        if (config.isValid()) {
            switch (config.bearerTypeFamily()) {
            case QNetworkConfiguration::Bearer2G:
            case QNetworkConfiguration::Bearer3G:
            case QNetworkConfiguration::Bearer4G:
                return true;
            default:
                break;
            }
        }
    }

    return false;
}


bool
ScApp::isOnline() const {
    return m_NetworkConfigurationManager.isOnline();
}

void
ScApp::onOnlineStateChanged(bool online) {
    Q_UNUSED(online)
    emit isOnlineChanged();
}

bool
ScApp::isUrl(const QString& str) const {
    QUrl url(str);
    return url.isValid();
}

QString ScApp::dataDir() const {
    return QStandardPaths::writableLocation(QStandardPaths::DataLocation);
}

QString ScApp::appDir() const {
    return QStringLiteral(QT_STRINGIFY(SAILFISH_DATADIR));
}

QString ScApp::logDir() const {
    return staticLogDir();
}

QString ScApp::staticLogDir() {
    return QStandardPaths::writableLocation(QStandardPaths::DataLocation) + QStringLiteral("/logs");
}

bool ScApp::unlink(const QString& filePath) const {
    return QFile::remove(filePath);
}

bool ScApp::copy(const QString& srcFilePath, const QString& dstFilePath) const {
    return QFile::copy(srcFilePath, dstFilePath);
}

bool ScApp::move(const QString& srcFilePath, const QString& dstFilePath) const {
    return QFile::rename(srcFilePath, dstFilePath);
}

bool ScApp::isDir(const QString& str) const {
    QDir d(str);
    return d.exists();
}

bool ScApp::isVodKey(const QVariant& var) const
{
    return IsVodKey(var);
}

bool ScApp::IsVodKey(const QVariant& var)
{
    return var.canConvert(QVariant::LongLong);
}

bool ScApp::isUrlKey(const QVariant& var) const
{
    return IsUrlKey(var);
}

bool ScApp::IsUrlKey(const QVariant& var)
{
    return var.type() == QVariant::String;
}

QString ScApp::filename(const QString& value) const
{
    return QFileInfo(value).fileName();
}

QString ScApp::makeTemporaryFile(const QString& pathTemplate) const
{
    return MakeTemporaryFile(pathTemplate);
}

QString ScApp::MakeTemporaryFile(const QString& pathTemplate)
{
    QTemporaryFile f(pathTemplate);
    if (f.open()) {
        f.setAutoRemove(false);
        auto path = f.fileName();
        f.close();
        return path;
    }

    return QString();
}
