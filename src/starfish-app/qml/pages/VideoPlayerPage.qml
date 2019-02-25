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

import QtQuick 2.0
import QtGraphicalEffects 1.0
import QtMultimedia 5.0
import Sailfish.Silica 1.0
import org.duckdns.jgressmann 1.0
import ".."

Page {
    id: page
    readonly property int startOffset: Math.floor(_startOffsetMs * 1000)
    property int _startOffsetMs: 0
    property int _seekFixup: 0
    property bool _startSeek: false
    property string title

    property int playbackAllowedOrientations: Orientation.Landscape | Orientation.LandscapeInverted
    backNavigation: controlPanel.open || !_hasSource

    readonly property int playbackOffset: streamPositonS
    readonly property int streamPositonS: Math.floor(mediaplayer.position / 1000)
    readonly property int streamDurationS: Math.ceil(mediaplayer.duration / 1000)
    property bool _forceBusyIndicator: false
    property bool _hasSource: !!("" + mediaplayer.source)
    property bool _showVideo: true
    property bool _paused: false
    property int _pauseCount: 0
    property var openHandler
    readonly property bool closed: _closed
    property bool _closed: false
    property bool _grabFrameWhenReady: false
    readonly property bool isPlaying: mediaplayer.playbackState === MediaPlayer.PlayingState

    signal videoFrameCaptured(string filepath)
    signal videoCoverCaptured(string filepath)
    signal videoThumbnailCaptured(string filepath)

//    onPlaybackOffsetChanged: {
//        console.debug("playback offset="+ playbackOffset)
//    }

    Timer {
        id: stallTimer
        interval: 10000
        onTriggered: {
            console.debug("stall timer expired")
            pause()
            controlPanel.open = true
        }
    }


    MediaPlayer {
        id: mediaplayer
        autoPlay: true

        onStatusChanged: {
            console.debug("media player status=" + status)
            switch (status) {
            case MediaPlayer.Buffering:
                console.debug("buffering")
                stallTimer.start()
                break
            case MediaPlayer.Stalled:
                console.debug("stalled")
                stallTimer.start()
                break
            case MediaPlayer.Buffered:
                console.debug("buffered")
                stallTimer.stop()
                if (_grabFrameWhenReady) {
                    _grabFrameWhenReady = false
                    _grabFrame()
                }
                break
            case MediaPlayer.EndOfMedia:
                console.debug("end of media")
                controlPanel.open = true
                break
            case MediaPlayer.Loaded:
                console.debug("loaded")
                if (metaData && metaData.title) {
                    page.title = metaData.title
                }
                break
            case MediaPlayer.InvalidMedia:
                console.debug("invalid media")
                controlPanel.open = true
                break
            }
        }

        onPlaybackStateChanged: {
            console.debug("media player playback state=" + playbackState)

            switch (playbackState) {
            case MediaPlayer.PlayingState:
                console.debug("playing")
                break
            case MediaPlayer.PausedState:
                console.debug("paused")
                break
            case MediaPlayer.StoppedState:
                console.debug("stopped")
                break
            default:
                console.debug("unhandled playback state")
                break
            }

            // apparently isPlaying isn't updated here yet, sigh
//            console.debug("isPlaying=" + isPlaying)

            _preventBlanking(playbackState === MediaPlayer.PlayingState)
        }

//        onVolumeChanged: {
//            console.debug("media player volume=" + volume)
//        }

        onPositionChanged: {
            // If the start offset seek ended up short of the target position,
            // correct iteratively
            if (_startSeek && position - _startOffsetMs < -1000) {
                _seekFixup += 1000
                console.debug("reseek from " + position + " to start offset " + _startOffsetMs + " + " + _seekFixup)
                if (_startOffsetMs + _seekFixup < duration) {
                    _seek(_startOffsetMs + _seekFixup)
                }
            }
        }
    }



    Item {
        id: thumbnailOutput
        property real factor: 1.0 / Math.max(videoOutput.width, videoOutput.height)
        width: Theme.iconSizeLarge * factor * videoOutput.width
        height: Theme.iconSizeLarge * factor * videoOutput.height


        ColorOverlay {
            anchors.fill: parent
            source: videoOutput
        }
    }

    Item {
        id: coverOutput
        property real factor: 1.0 / Math.max(videoOutput.width, videoOutput.height)
        width: 512 * factor * videoOutput.width
        height: 512 * factor * videoOutput.height


        ColorOverlay {
            anchors.fill: parent
            source: videoOutput
        }
    }


    Rectangle {
        id: videoOutputRectangle
        anchors.fill: parent
        color: "black"
        visible: _showVideo

        onVisibleChanged: {
            if (visible) {
                page.allowedOrientations = playbackAllowedOrientations
            }
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            source: mediaplayer
            fillMode: VideoOutput.PreserveAspectFit
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: _forceBusyIndicator || (mediaplayer.status === MediaPlayer.Stalled)
            size: BusyIndicatorSize.Medium
        }

// circle looks terrible and blocks out video
//        ProgressCircle {
//            anchors.centerIn: parent
//            visible: value < 1
//            value: mediaplayer.bufferProgress
//            width: Theme.itemSizeLarge
//            height: Theme.itemSizeLarge
//        }

        Rectangle {
            id: seekRectangle
//            color: Theme.rgba(Theme.secondaryColor, 0.5)
            color: "white"
            width: Theme.horizontalPageMargin * 2 + seekLabel.width
            height: 2*Theme.fontSizeExtraLarge
            visible: false
            anchors.centerIn: parent

            Label {
                id: seekLabel
                //color: Theme.primaryColor
                color: "black"
                text: "Sir Skipalot"
                font.bold: true
                font.pixelSize: Theme.fontSizeExtraLarge
                anchors.centerIn: parent
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            property real startx: -1
            property real starty: -1
//            readonly property real dragDistance: Theme.iconSizeLarge / 2
            readonly property real dragDistance: Theme.startDragDistance

            property bool held: false
            property int seekType: -1
            property real initialVolume: 0

            onPositionChanged: function (e) {
//                console.debug("x=" + e.x + " y="+e.y)
                e.accepted = true

                if (startx >= 0 && starty >= 0) {
                    var dx = e.x - startx
                    var dy = e.y - starty

                    if (-1 === seekType) {
                        if (Math.abs(dx) >= dragDistance ||
                            Math.abs(dy) >= dragDistance) {

                            if (Math.abs(dx) >= Math.abs(dy)) {
                                seekType = 0
                            } else {
                                seekType = 1
                            }
                        }
                    }

                    seekRectangle.visible = seekType !== -1
                    switch (seekType) {
                    case 0: { // position
                        var skipSeconds = computePositionSeek(dx)
                        var streamPosition = Math.max(0, Math.min(streamPositonS + skipSeconds, streamDurationS))
                        seekLabel.text = (dx >= 0 ? "+" : "-") + _toTime(Math.abs(skipSeconds)) + " (" + _toTime(streamPosition) + ")"
                    } break
                    case 1: { // volume
                        var volumeChange = -(dy / parent.height)
                        var volume = Math.max(0, Math.min(initialVolume + volumeChange, 1))
                        seekLabel.text = "Volume " + (volume * 100).toFixed(0) + "%"
                        mediaplayer.volume = volume
                    } break
                    }
                }
            }

            onPressed: function (e) {
//                console.debug("pressed")
                if (!controlPanel.open) {
                    startx = e.x;
                    starty = e.y;
                    initialVolume = mediaplayer.volume
                }
            }

            onReleased: function (e) {
//                console.debug("released")

                var dx = e.x - startx
                var dy = e.y - starty

                switch (seekType) {
                case 0: { // position

                        var skipSeconds = computePositionSeek(dx)
                        if (Math.abs(skipSeconds) >= 3) { // prevent small skips
                            var streamPosition = Math.floor(Math.max(0, Math.min(streamPositonS + skipSeconds, streamDurationS)))
                            if (streamPosition !== streamPositonS) {
                                console.debug("skip to=" + streamPosition)
                                _startSeek = false
                                _seek(streamPosition * 1000)
                            }
                        }
                } break
                case 1: { // volume
//                    var volumeChange = -dy / dragDistance
//                    var volume = Math.max(0, Math.min(mediaplayer.volume + volumeChange, 1))
//                    mediaplayer.volume = volume
                } break
                default: {
                    if (!held) {
                        if (controlPanel.open) {
                            controlPanel.open = false
//                            mediaplayer.play()
                        } else {
//                            mediaplayer.pause()
                            controlPanel.open = true
                        }
                    }
                } break
                }

                seekType = -1
                held = false
                startx = -1
                starty = -1
                seekRectangle.visible = false
                initialVolume = 0
            }

//            onEntered: {
//                console.debug("entered")
//            }

//            onExited: {
//                console.debug("exited")
//                e.accepted = true
//            }

            onPressAndHold: function (e) {
                console.debug("onPressAndHold")
                e.accepted = true
                held = true
            }

//            onClicked: function (e) {
//                console.debug("clicked")
//                e.accepted = true

//                seekRectangle.visible = false
//                controlPanel.open = !controlPanel.open
//            }

            function computePositionSeek(dx) {
                var sign = dx < 0 ? -1 : 1
                var absDx = sign * dx
                return sign * Math.pow(absDx / dragDistance, 1 + absDx / Screen.width)
            }

            DockedPanel {
                id: controlPanel
                width: parent.width
                height: 2*Theme.itemSizeLarge
                dock: Dock.Bottom

                onOpenChanged: {
                    console.debug("control panel open=" + open)
                    //positionSlider.value = Math.max(0, mediaplayer.position)

//                    // Grab frame when closing again, better to have it than
//                    // to miss it :D
//                    if (_hasSource && mediaplayer.status === MediaPlayer.Buffered) {
//                        _grabFrame()
//                    }
                }

                Column {
                    width: parent.width

                    Slider {
                        id: positionSlider
                        width: parent.width
                        maximumValue: Math.max(1, mediaplayer.duration)

                        Connections {
                            target: mediaplayer
                            onPositionChanged: {
                                if (!positionSlider.down && !seekTimer.running) {
                                    positionSliderConnections.target = null
                                    positionSlider.value = Math.max(0, mediaplayer.position)
                                    positionSliderConnections.target = positionSlider
                                }
                            }
                        }

                        Connections {
                            id: positionSliderConnections
                            target: positionSlider
                            onValueChanged: {
                                console.debug("onValueChanged " + positionSlider.value + " down=" + positionSlider.down)
                                seekTimer.restart()
                            }
                        }

                        Timer {
                            id: seekTimer
                            running: false
                            interval: 500
                            repeat: false
                            onTriggered: {
                                _startSeek = false
                                _seek(positionSlider.sliderValue)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: first.height

                        Item {
                            id: leftMargin
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.left: parent.left
                        }

                        Item {
                            id: rightMargin
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.right: parent.right
                        }

                        Label {
                            id: first
                            anchors.left: leftMargin.right
                            text: _toTime(streamPositonS)
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            anchors.right: rightMargin.left
                            text: _toTime(streamDurationS)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.highlightColor
                        }
                    }

                    Item {
                        width: parent.width
                        height: functionalButtonRow.height

                        Item {
                            id: leftMargin2
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.left: parent.left
                        }

                        Item {
                            id: rightMargin2
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.right: parent.right
                        }

                        Row {
                            id: functionalButtonRow
                            anchors.centerIn: parent
                            spacing: Theme.paddingLarge

                            IconButton {
                                icon.source: isPlaying ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    console.debug("play/pause")
                                    switch (mediaplayer.playbackState) {
                                    case MediaPlayer.PlayingState:
                                        page.pause()
                                        break
                                    case MediaPlayer.PausedState:
                                    case MediaPlayer.StoppedState:
                                        switch (mediaplayer.status) {
                                        case MediaPlayer.Buffered:
                                            page.resume()
                                            break
                                        case MediaPlayer.EndOfMedia:
                                            controlPanel.open = false
                                            _startSeek = true
                                            _seek(_startOffsetMs)
                                            mediaplayer.play()
                                            break
                                        }
                                        break
                                    }
                                }
                            }

                            IconButton {
                                visible: false
    //                            source: "image://theme/icon-m-close"
                                icon.source: "image://theme/icon-m-back"

                                anchors.verticalCenter: parent.verticalCenter

                                onClicked: {
                                    console.debug("close")
                                    pageStack.pop()
                                }
                            }

                            IconButton {
                                icon.source: "image://theme/icon-m-folder"
                                visible: !!openHandler

                                anchors.verticalCenter: parent.verticalCenter

                                onClicked: {
                                    console.debug("open")
                                    page.pause()
                                    openHandler()
                                }
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: rightMargin2.left

                            Image {
                                visible: _hasSource
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                sourceSize: Qt.size(width, height)
                                source: ((mediaplayer.source || "") + "").indexOf("file://") === 0 ? "image://theme/icon-s-like" : "image://theme/icon-s-cloud-download"
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: leftMargin2.right

                            Label {
                                visible: videoOutput.sourceRect.width > 0 && videoOutput.sourceRect.height > 0
                                text: videoOutput.sourceRect.width + "x" + videoOutput.sourceRect.height
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.highlightColor
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Global.videoPlayerPage = page
    }

    Component.onDestruction: {
        console.debug("destruction")
        _preventBlanking(false)
        _closed = true
        Global.videoPlayerPage = null
        // save current frame
        mediaplayer.pause()
//        if (mediaplayer.playbackState === MediaPlayer.PausedState) {
//            _grabFrame()
//        }
    }

//    Timer {
//        id: frameCapturedSignalTimer
//        interval: 1
//        repeat: false
//        onRunningChanged: {
//            console.debug("frame capture timer running=" + running)
//        }

//        onTriggered: {
//            console.debug("frame capture timer triggered begin")
//            videoFrameCaptured(Global.videoFramePath)
//            console.debug("frame capture timer triggered end")
//        }
//    }


    Timer {
        id: busyTimer
        interval: 1000
        onTriggered: {
            console.debug("_forceBusyIndicator = false")
            _forceBusyIndicator = false
        }
    }

    onStatusChanged: {
        console.debug("page status=" + status)
        switch (status) {
        case PageStatus.Deactivating: {
            console.debug("page status=deactivating")
            // moved here from panel open/close, seems to be less disruptive to
            // user experience
            if (_hasSource && mediaplayer.status === MediaPlayer.Buffered) {
                _grabFrame()
            }
            //pause()
        } break
        case PageStatus.Activating:
            console.debug("page status=activating")
            //resume()
            break
        }
    }

    function play(url, offset, saveScreenShot) {
        console.debug("play offset=" + offset + " url=" + url + " save screen shot=" + saveScreenShot)
        mediaplayer.source = url
        mediaplayer.play()
        controlPanel.open = false
        _startOffsetMs = offset * 1000
        _grabFrameWhenReady = !!saveScreenShot
        _startSeek = false
        _seekFixup = 0
        _pauseCount = 0;
        _paused = false
        if (_showVideo && _startOffsetMs > 0) {
            console.debug("seek to " + _startOffsetMs)
            _startSeek = true
            _seek(_startOffsetMs)
        }
    }

    function pause() {
        _pauseCount += 1
        console.debug("pause count="+ _pauseCount)
        if (isPlaying) {
            console.debug("video player page pause playback")
//            mediaplayer.pause()

            _paused = true
            mediaplayer.pause()
        }

        if (mediaplayer.playbackState === MediaPlayer.PausedState) {
            _grabFrame()
        }
    }

    function resume() {
        _pauseCount -= 1
        console.debug("pause count="+ _pauseCount)
        if (_pauseCount === 0 && _paused) {
            console.debug("video player page resume playback")
            _paused = false
            mediaplayer.play()
            // toggle item visibility to to unfreeze video
            // after coming out of device lock
            videoOutputRectangle.visible = false
            videoOutputRectangle.visible = true
        }
    }

    function _stopPlayback() {
        pause()


//        if (mediaplayer.playbackState === MediaPlayer.PlayingState) {
//            mediaplayer.pause()
//            _paused = true
//        } else {
//            _paused = false
//        }

//        if (mediaplayer.playbackState === MediaPlayer.PausedState) {
//            _grabFrame()
//        }
    }

    function _toTime(n) {
        return Global.secondsToTimeString(n)
    }

    function _seek(position) {
        _forceBusyIndicator = true
        console.debug("_forceBusyIndicator=true")
        busyTimer.restart()
        mediaplayer.seek(position)
    }

    function _grabFrame() {
        thumbnailOutput.grabToImage(function (a) {
            a.saveToFile(Global.videoThumbnailPath)
            videoThumbnailCaptured(Global.videoThumbnailPath)
        })

        coverOutput.grabToImage(function (a) {
            a.saveToFile(Global.videoCoverPath)
            videoCoverCaptured(Global.videoCoverPath)
        })
    }

    function _preventBlanking(b) {
        try {
            KeepAlive.preventBlanking = b
            console.debug("prevent blank="+KeepAlive.preventBlanking)
        } catch (e) {
            console.debug("prevent blanking not available")
        }
    }
}

