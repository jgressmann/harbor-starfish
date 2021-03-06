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

#include <QDir>
#include <QGuiApplication>
#include <QMetaObject>
#include <qqml.h>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickView>
#include <QStandardPaths>
#include <QSettings>


#include "Sc2LinksDotCom.h"
#include "Sc2CastsDotCom.h"
#include "ScSqlVodModel.h"
#include "ScVodDatabaseDownloader.h"
#include "ScVodDataManager.h"
#include "ScApp.h"
#include "ScVodman.h"
#include "ScRecentlyWatchedVideos.h"
#include "VMQuickYTDLDownloader.h"
#include "ScMatchItem.h"
#include "ScVodFileItem.h"
#include "ScVodPlaylist.h"
#include "ScConfigValue.h"

#include <sailfishapp.h>

#include <stdio.h>

static QObject *dataManagerProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return new ScVodDataManager();
}

static QObject *appProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return new ScApp();
}

static QObject *vmQuickYTDLDownloader(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return new VMQuickYTDLDownloader();
}

static void setupLogging();
static void teardownLogging();

int
main(int argc, char *argv[]) {

    int result = 0;
    {
        QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
        setupLogging(); // need to have the app paths

        QSettings settings;
        ScConfigValue::SetSettings(&settings);

        // Vodman
        qmlRegisterUncreatableType<VMVodEnums>(VODMAN_LIB_NAMESPACE, VODMAN_LIB_VERSION_MAJOR, VODMAN_LIB_VERSION_MINOR, "VM", QStringLiteral("wrapper around C++ enums"));
        qmlRegisterSingletonType<VMQuickYTDLDownloader>(VODMAN_LIB_NAMESPACE, VODMAN_LIB_VERSION_MAJOR, VODMAN_LIB_VERSION_MINOR, "YTDLDownloader", vmQuickYTDLDownloader);

        // Starfish
        qRegisterMetaType<VMVodEnums::Error>("VMVodEnums::Error");
        qRegisterMetaType<VMVodEnums::Format>("VMVodEnums::Format");
        qRegisterMetaType<ScVodDataManagerWorker::ThumbnailError>("ScVodDataManagerWorker::ThumbnailError");

        qmlRegisterType<ScSqlVodModel>(STARFISH_NAMESPACE, 1, 0, "SqlVodModel");
        qmlRegisterType<ScVodDatabaseDownloader>(STARFISH_NAMESPACE, 1, 0, "VodDatabaseDownloader");
        qmlRegisterType<Sc2LinksDotCom>(STARFISH_NAMESPACE, 1, 0, "Sc2LinksDotComScraper");
        qmlRegisterType<Sc2CastsDotCom>(STARFISH_NAMESPACE, 1, 0, "Sc2CastsDotComScraper");
        qmlRegisterType<ScVodPlaylist>(STARFISH_NAMESPACE, 1, 0, "VodPlaylist");
        qmlRegisterType<ScConfigValue>(STARFISH_NAMESPACE, 1, 0, "ConfigValue");

        qmlRegisterUncreatableType<ScVodScraper>(STARFISH_NAMESPACE, 1, 0, "VodScraper", "VodScraper");
        qmlRegisterUncreatableType<ScVodman>(STARFISH_NAMESPACE, 1, 0, "Vodman", "Vodman");

        qmlRegisterUncreatableType<ScEnums>(STARFISH_NAMESPACE, 1, 0, "Sc", QStringLiteral("wrapper around C++ enums"));
        qmlRegisterUncreatableType<ScRecentlyWatchedVideos>(STARFISH_NAMESPACE, 1, 0, "RecentlyWatchedVideos", "RecentlyWatchedVideos");
        qmlRegisterUncreatableType<ScMatchItem>(STARFISH_NAMESPACE, 1, 0, "Match", "Match");
        qmlRegisterUncreatableType<ScUrlShareItem>(STARFISH_NAMESPACE, 1, 0, "UrlShare", "UrlShare");
        qmlRegisterUncreatableType<ScVodFileItem>(STARFISH_NAMESPACE, 1, 0, "VodFile", "VodFile");

        qmlRegisterSingletonType<ScApp>(STARFISH_NAMESPACE, 1, 0, "App", appProvider);
        qmlRegisterSingletonType<ScVodDataManager>(STARFISH_NAMESPACE, 1, 0, "VodDataManager", dataManagerProvider);

        {
            QScopedPointer<QQuickView> view(SailfishApp::createView());
            view->setSource(SailfishApp::pathToMainQml());
            view->requestActivate();
            view->show();
            result = app->exec();
        }
    }

    teardownLogging();
    return result;
}


static FILE* s_LogFile;
static
void addMessage(
        const char* timeStamp,
        const char* type,
        const char* message,
        const char* file,
        int line,
        const char* function) {

    fprintf(stderr, "%s|%s|%s(%d)|%s|%s\n", timeStamp, type, file, line, function, message);
    fprintf(s_LogFile, "%s|%s|%s(%d)|%s|%s\n", timeStamp, type, file, line, function, message);
}

static const QString s_TimeStampFormatter = QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz");
static
void
messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg) {
    auto localMsg = msg.toLocal8Bit();
    auto timeStamp = QDateTime::currentDateTime().toString(s_TimeStampFormatter).toLocal8Bit();
    switch (type) {
    case QtDebugMsg:
        addMessage(timeStamp.constData(), "Debug", localMsg.constData(), context.file, context.line, context.function);
        break;
    case QtInfoMsg:
        addMessage(timeStamp.constData(), "Info", localMsg.constData(), context.file, context.line, context.function);
        break;
    case QtWarningMsg:
        addMessage(timeStamp.constData(), "Warning", localMsg.constData(), context.file, context.line, context.function);
        break;
    case QtCriticalMsg:
        addMessage(timeStamp.constData(), "Critical", localMsg.constData(), context.file, context.line, context.function);
        fflush(s_LogFile);
        break;
    case QtFatalMsg:
        addMessage(timeStamp.constData(), "Fatal", localMsg.constData(), context.file, context.line, context.function);
        fclose(s_LogFile);
        abort();
    }
}

static
void
deleteOldLogs(const QString& logDir) {
    QDir dir;
    dir.setFilter(QDir::Files | QDir::Hidden | QDir::NoSymLinks);
    dir.setNameFilters(QStringList() << QStringLiteral(STARFISH_APP_NAME "-*.txt"));
    dir.setSorting(QDir::Time | QDir::Reversed);
    dir.setPath(logDir);

    auto ageThreshold = QDate::currentDate().addDays(-7);

    auto list = dir.entryInfoList();
    for (int i = 0; i < list.size(); ++i) {
        if (list[i].lastModified() >= QDateTime(ageThreshold)) {
            break;
        }

        QFile::remove(list[i].absoluteFilePath());
    }
}

static
void
teardownLogging() {
    if (s_LogFile) {
        fclose(s_LogFile);
        s_LogFile = nullptr;
    }
}

static
void
setupLogging() {
    auto logDir = ScApp::staticLogDir();
    QDir().mkpath(logDir);
    deleteOldLogs(logDir);
    auto logFilePath = QStringLiteral("%1/" STARFISH_APP_NAME "-%2.txt").arg(logDir, QDate::currentDate().toString(QStringLiteral("yyyyMMdd")));
    s_LogFile = fopen(logFilePath.toLocal8Bit(), "a");
    if (s_LogFile) {
        qInstallMessageHandler(messageHandler);
    }
}
