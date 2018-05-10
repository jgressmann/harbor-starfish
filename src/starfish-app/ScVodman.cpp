#include "ScVodman.h"
#include <vodman/VMVodMetaDataDownload.h>
#include <vodman/VMVodFileDownload.h>
#include <QDBusConnection>
#include <QMutexLocker>
#include <QDataStream>

ScVodman::~ScVodman()
{
    delete m_Service;
}

ScVodman::ScVodman(QObject *parent)
    : QObject(parent)
    , m_Lock(QMutex::Recursive)
{
    m_MaxFile = 1;
    m_MaxMeta = 4;
    m_CurrentFile = 0;
    m_CurrentMeta = 0;

    QDBusConnection connection = QDBusConnection::sessionBus();
    m_Service = new org::duckdns::jgressmann::vodman::service("org.duckdns.jgressmann.vodman.service", "/instance", connection);
    m_Service->setParent(this);

    connect(
                m_Service,
                &org::duckdns::jgressmann::vodman::service::vodFileDownloadRemoved,
                this,
                &ScVodman::onVodFileDownloadRemoved);

    connect(
                m_Service,
                &org::duckdns::jgressmann::vodman::service::vodFileDownloadChanged,
                this,
                &ScVodman::onVodFileDownloadChanged);



    connect(
                m_Service,
                &org::duckdns::jgressmann::vodman::service::vodMetaDataDownloadCompleted,
                this,
                &ScVodman::onVodFileMetaDataDownloadCompleted);
}

void
ScVodman::startFetchMetaData(qint64 token, const QString& url) {
    if (token < 0) {
        qWarning() << "invalid token" << token << "meta data fetch not started";
        return;
    }

    if (url.isEmpty()) {
        qWarning() << "invalid url" << url << "meta data fetch not started";
        return;
    }

    QMutexLocker g(&m_Lock);
    Request r;
    r.type = RT_MetaData;
    r.url = url;
    r.formatIndex = 0;
    r.token = 0;


    if (m_MaxMeta > 0 && m_CurrentMeta == m_MaxMeta) {
        m_PendingMetaDataRequests << qMakePair(token, r);
    } else {
        ++m_CurrentMeta;
        issueRequest(token, r);
    }
}

void
ScVodman::issueRequest(qint64 token, const Request& request) {
    m_ActiveRequests.insert(token, request);
    auto reply = m_Service->newToken();
    auto watcher = new QDBusPendingCallWatcher(reply, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, &ScVodman::onNewTokenReply);
    m_PendingDBusResponses.insert(watcher, token);
}

void
ScVodman::startFetchFile(qint64 token, const VMVod& vod, int formatIndex, const QString& filePath) {
    if (token < 0) {
        qWarning() << "invalid token" << token << "file fetch not started";
        return;
    }

    if (!vod.isValid()) {
        qWarning() << "invalid vod";
        return;
    }

    if (formatIndex < 0 || formatIndex >= vod.formats()) {
        qDebug() << "invalid vod format index"<< "file fetch not started";
        return;
    }

    if (filePath.isEmpty()) {
        qWarning() << "invalid file path" << filePath << "file fetch not started";
        return;
    }

    QMutexLocker g(&m_Lock);
    Request r;
    r.type = RT_File;
    r.vod = vod;
    r.formatIndex = formatIndex;
    r.token = 0;
    r.filePath = filePath;

    if (m_MaxMeta > 0 && m_CurrentMeta == m_MaxMeta) {
        m_PendingFileRequests << qMakePair(token, r);
    } else {
        ++m_CurrentFile;
        issueRequest(token, r);
    }
}

void
ScVodman::onVodFileMetaDataDownloadCompleted(qint64 token, const QByteArray& result) {

    qDebug() << "enter" << token;
    QMutexLocker g(&m_Lock);
    auto requestId = m_MetaDataTokenMap.value(token, -1);
    if (requestId >= 0) {

        VMVodMetaDataDownload download;
        {
            QDataStream s(result);
            s >> download;
        }

        qDebug() << "mine" << requestId << download;

        if (download.isValid()) {
            if (download.error() == VMVodEnums::VM_ErrorNone) {
                emit metaDataDownloadCompleted(requestId, download.vod());
            } else {
                emit downloadFailed(requestId, download.error());
            }
        } else {
            if (download.error() != VMVodEnums::VM_ErrorNone) {
                emit downloadFailed(requestId, download.error());
            } else {
                emit downloadFailed(requestId, VMVodEnums::VM_ErrorUnknown);
            }
        }

        m_MetaDataTokenMap.remove(requestId);
        m_ActiveRequests.remove(requestId);
        --m_CurrentMeta;
        scheduleNextMetaDataRequest();
    } else {
        // nop
    }

    qDebug() << "exit" << token;
}


void
ScVodman::onNewTokenReply(QDBusPendingCallWatcher *self) {
    QMutexLocker g(&m_Lock);
    self->deleteLater();
    QDBusPendingReply<qint64> reply = *self;
    auto requestId = m_PendingDBusResponses[self];
    m_PendingDBusResponses.remove(self);
    Request& r = m_ActiveRequests[requestId];
    if (reply.isValid()) {
        r.token = reply.value();
        switch (r.type) {
        case RT_MetaData: {
            auto reply = m_Service->startFetchVodMetaData(r.token, r.url);
            auto watcher = new QDBusPendingCallWatcher(reply, this);
            connect(watcher, &QDBusPendingCallWatcher::finished, this, &ScVodman::onMetaDataDownloadReply);
            m_PendingDBusResponses.insert(watcher, requestId);
            m_MetaDataTokenMap.insert(r.token, requestId);
        } break;
        case RT_File: {
            VMVodFileDownloadRequest serviceRequest;
            serviceRequest.filePath = r.filePath;
            serviceRequest.description = r.vod.description();
            serviceRequest.format = r.vod.data()._formats[r.formatIndex];
            QByteArray b;
            {
                QDataStream s(&b, QIODevice::WriteOnly);
                s << serviceRequest;
            }
            auto reply = m_Service->startFetchVodFile(r.token, b);
            auto watcher = new QDBusPendingCallWatcher(reply, this);
            connect(watcher, &QDBusPendingCallWatcher::finished, this, &ScVodman::onFileDownloadReply);
            m_PendingDBusResponses.insert(watcher, requestId);
            m_FileTokenMap.insert(r.token, requestId);
        } break;
        default:
            emit downloadFailed(requestId, VMVodEnums::VM_ErrorUnknown);
            break;
        }
    } else {
         qDebug() << "invalid new token reply" << reply.error();
         m_ActiveRequests.remove(requestId);
         switch (r.type) {
         case RT_MetaData:
             --m_CurrentMeta;
             scheduleNextMetaDataRequest();
             break;
         case RT_File:
             --m_CurrentFile;
             scheduleNextFileRequest();
             break;
         }
         emit downloadFailed(requestId, VMVodEnums::VM_ErrorServiceUnavailable);
    }
}


void
ScVodman::onMetaDataDownloadReply(QDBusPendingCallWatcher *self) {
    QMutexLocker g(&m_Lock);
    self->deleteLater();
    QDBusPendingReply<> reply = *self;
    auto requestId = m_PendingDBusResponses[self];
    m_PendingDBusResponses.remove(self);
    Request& r = m_ActiveRequests[requestId];
    if (reply.isValid()) {
        // nothing to do
    } else {
        qDebug() << "invalid metadata download reply for" << r.url  << "error" << reply.error();
        m_ActiveRequests.remove(requestId);
        --m_CurrentMeta;
        emit downloadFailed(requestId, VMVodEnums::VM_ErrorServiceUnavailable);
        scheduleNextMetaDataRequest();
    }
}

void
ScVodman::onFileDownloadReply(QDBusPendingCallWatcher *self) {
    QMutexLocker g(&m_Lock);
    self->deleteLater();
    QDBusPendingReply<> reply = *self;
    auto requestId = m_PendingDBusResponses[self];
    m_PendingDBusResponses.remove(self);
    Request& r = m_ActiveRequests[requestId];
    if (reply.isValid()) {
        // nothing to do
    } else {
        qDebug() << "invalid file download reply for" << r.url  << "error" << reply.error();
        m_ActiveRequests.remove(requestId);
        --m_CurrentFile;
        emit downloadFailed(requestId, VMVodEnums::VM_ErrorServiceUnavailable);
        scheduleNextFileRequest();
    }
}

qint64
ScVodman::newToken() {
    return m_TokenGenerator++;
}

void
ScVodman::onVodFileDownloadRemoved(qint64 handle, const QByteArray& result)
{
    qDebug() << "enter" << handle;

    QMutexLocker g(&m_Lock);
    auto requestId = m_FileTokenMap.value(handle, -1);
    if (requestId >= 0) {

        VMVodFileDownload download;
        {
            QDataStream s(result);
            s >> download;
        }

        if (download.isValid()) {
            emit fileDownloadCompleted(requestId, download);
        } else {
            emit downloadFailed(requestId, download.error());
        }

        m_FileTokenMap.remove(handle);
        m_ActiveRequests.remove(requestId);
        --m_CurrentFile;
        scheduleNextFileRequest();
    }

    qDebug() << "exit" << handle;
}

void
ScVodman::onVodFileDownloadChanged(qint64 handle, const QByteArray& result)
{
    qDebug() << "enter" << handle;

    QMutexLocker g(&m_Lock);
    auto requestId = m_FileTokenMap.value(handle, -1);
    if (requestId >= 0) {
        VMVodFileDownload download;
        {
            QDataStream s(result);
            s >> download;
        }

        emit fileDownloadChanged(requestId, download);
    }

    qDebug() << "exit" << handle;
}

void
ScVodman::cancel(qint64 token) {
    QMutexLocker g(&m_Lock);

    for (int i = 0; i < m_PendingFileRequests.size(); ++i) {
        const auto& pair = m_PendingFileRequests[i];
        if (pair.first == token) {
            m_PendingFileRequests.removeAt(i);
            return;
        }
    }

    for (int i = 0; i < m_PendingMetaDataRequests.size(); ++i) {
        const auto& pair = m_PendingMetaDataRequests[i];
        if (pair.first == token) {
            m_PendingMetaDataRequests.removeAt(i);
            return;
        }
    }

    auto beg = m_FileTokenMap.begin();
    auto end = m_FileTokenMap.end();
    for (auto it = beg; it != end; ++it) {
        if (it.value() == token) {
            m_Service->cancelFetchVodFile(it.key(), false);
            return;
        }
    }
}

void
ScVodman::cancel() {
    QMutexLocker g(&m_Lock);
    m_PendingFileRequests.clear();
    m_PendingMetaDataRequests.clear();
    foreach (auto serviceToken, m_FileTokenMap.keys()) {
        m_Service->cancelFetchVodFile(serviceToken, false);
    }
}

void
ScVodman::scheduleNextFileRequest() {
    if (!m_PendingFileRequests.isEmpty() &&
        (m_MaxFile <= 0 || m_CurrentFile < m_MaxFile)) {
        auto pair = m_PendingFileRequests.front();
        m_PendingFileRequests.pop_front();
        ++m_CurrentFile;
        issueRequest(pair.first, pair.second);
    }
}

void
ScVodman::scheduleNextMetaDataRequest() {
    if (!m_PendingMetaDataRequests.isEmpty() &&
        (m_MaxMeta <= 0 || m_CurrentMeta < m_MaxMeta)) {
        auto pair = m_PendingMetaDataRequests.front();
        m_PendingMetaDataRequests.pop_front();
        ++m_CurrentMeta;
        issueRequest(pair.first, pair.second);
    }
}

void
ScVodman::setMaxConcurrentMetaDataDownloads(int value) {
    if (value <= 0) {
        qCritical() << "invalid max meta data downloads" << value;
        return;
    }

    QMutexLocker g(&m_Lock);

    if (m_MaxMeta != value) {
        m_MaxMeta = value;
        emit maxConcurrentMetaDataDownloadsChanged();
    }
}