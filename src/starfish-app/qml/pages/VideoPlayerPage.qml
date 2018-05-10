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

import QtQuick 2.0
import QtMultimedia 5.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import org.duckdns.jgressmann 1.0
import ".."

Page {
    id: page
    property alias source: mediaplayer.source
    property int startOffsetMs: 0

    property int playbackAllowedOrientations: Orientation.Landscape | Orientation.LandscapeInverted
    backNavigation: controlPanel.open || _showMenu

    readonly property int streamPositonS: Math.floor(mediaplayer.position / 1000)
    readonly property int streamDurationS: Math.ceil(mediaplayer.duration / 1000)
    property bool _forceBusyIndicator: false
    property bool _hasSource: !!("" + source)
    property bool _showMenu: !_hasSource || _forceShowMenu
    property bool _showVideo: _hasSource && !_forceShowMenu
    property bool _forceShowMenu: false
    property bool _pausedOnPageDeactivation: false

    onSourceChanged: {
        console.debug("onSourceChanged " + source)
    }


    MediaPlayer {
        id: mediaplayer
        autoPlay: true

        onStatusChanged: {
            console.debug("media player status=" + status)
            if (status === MediaPlayer.Buffering) {
                console.debug("buffering")
            } else if (status === MediaPlayer.Stalled) {
                console.debug("stalled")
            } else if (status === MediaPlayer.Buffered) {
                console.debug("buffered")
            } else if (status === MediaPlayer.EndOfMedia) {
                console.debug("end of media")
                controlPanel.open = true
            }

//            _forceBusyIndicator = false
//            console.debug("_forceBusyIndicator=false")
        }

//        onBufferProgressChanged: {
//            console.debug("media player buffer progress=" + bufferProgress)
//        }

        onPlaybackStateChanged: {
            console.debug("media player playback state=" + playbackState)

        }

//        onVolumeChanged: {
//            console.debug("media player volume=" + volume)
//        }
    }

    Rectangle {
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
            color: Theme.rgba(Theme.secondaryColor, 0.5)
            width: Theme.horizontalPageMargin * 2 + seekLabel.width
            height: 2*Theme.fontSizeMedium
            visible: false
            anchors.centerIn: parent

            Label {
                id: seekLabel
                color: Theme.primaryColor
                text: "Sir Skipalot"
                font.bold: true
                anchors.centerIn: parent
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            property real startx: -1
            property real starty: -1
            readonly property real dragDistance: Theme.iconSizeMedium / 2
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
                        var skipSeconds = dx / dragDistance
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
                console.debug("pressed")
                if (!controlPanel.open) {
                    startx = e.x;
                    starty = e.y;
                    initialVolume = mediaplayer.volume
                }
            }

            onReleased: function (e) {
                console.debug("released")

                var dx = e.x - startx
                var dy = e.y - starty

                switch (seekType) {
                case 0: { // position

                        var skipSeconds = dx / dragDistance
                        var streamPosition = Math.floor(Math.max(0, Math.min(streamPositonS + skipSeconds, streamDurationS)))
                        if (streamPosition !== streamPositonS) {
                            console.debug("skip to=" + streamPosition)
                            _seek(streamPosition * 1000)
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

            DockedPanel {
                id: controlPanel
                width: parent.width
                height: 2*Theme.itemSizeLarge
                dock: Dock.Bottom

                onOpenChanged: {
                    console.debug("control panel open=" + open)
                    positionSlider.value = Math.max(0, mediaplayer.position)
                }

                Column {
                    width: parent.width

                    Slider {
                        id: positionSlider
                        width: parent.width
                        maximumValue: Math.max(1, mediaplayer.duration)
                        onValueChanged: {
                            console.debug("onValueChanged " + value)
                            if (down) {
                                _seek(sliderValue)
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

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingLarge

                        IconButton {
                            icon.source: mediaplayer.playbackState === MediaPlayer.PlayingState ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                console.debug("play/pause")
                                switch (mediaplayer.playbackState) {
                                case MediaPlayer.PlayingState:
                                    mediaplayer.pause()
                                    break
                                case MediaPlayer.PausedState:
                                case MediaPlayer.StoppedState:
                                    mediaplayer.play()
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

                            anchors.verticalCenter: parent.verticalCenter

                            onClicked: {
                                console.debug("menu")
                                mediaplayer.pause()
                                controlPanel.open = false
                                _forceShowMenu = true
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (_showVideo && startOffsetMs > 0) {
            console.debug("seek to " + startOffsetMs)
            _seek(startOffsetMs)
        }
    }



    Timer {
        id: busyTimer
        interval: 1000
        onTriggered: {
            console.debug("_forceBusyIndicator = false")
            _forceBusyIndicator = false
        }
    }

    ButtonLayout {
        id: contentSelection
        anchors.centerIn: parent
        visible: _showMenu

        onVisibleChanged: {
            if (visible) {
                page.allowedOrientations = window.allowedOrientations
            }
        }

        Button {
            text: "Open from clipboard"
            enabled: Clipboard.hasText && App.isUrl(Clipboard.text)
            onClicked: _play(Clipboard.text)
        }

        Button {
            text: "Open file"

            onClicked: {
                allowedOrientations = window.allowedOrientations
                pageStack.push(filePickerPage)
            }

            Component {
                id: filePickerPage
                FilePickerPage {
                    onSelectedContentPropertiesChanged: {
                        var path = selectedContentProperties.filePath
                        if (path) {
                            pageStack.pop(page, PageStackAction.Immediate)
                            _play(path)
                        }
                    }
                }
            }
        }
    }

    onStatusChanged: {
        console.debug("page status=" + page.status)
        switch (page.status) {
        case PageStatus.Deactivating: {
            if (mediaplayer.playbackState === MediaPlayer.PlayingState) {
                mediaplayer.pause()
                _pausedOnPageDeactivation = true
            } else {
                _pausedOnPageDeactivation = false
            }

            if (mediaplayer.playbackState === MediaPlayer.PausedState) {
                settingPlaybackOffset.value = mediaplayer.position / 1000

                videoOutput.grabToImage(function (a) {
//                    console.debug("video frame grabbed")
//                    App.unlink(Global.videoFramePath)
//                    console.debug("unlink")
                    //var success = a.saveToFile(Global.videoFramePath)
                    //console.debug("save frame to path=" + path + " success=" + success)
                    a.saveToFile(Global.videoFramePath)
                })
            }
        } break
        case PageStatus.Activating:
            if (_pausedOnPageDeactivation) {
                mediaplayer.play();
            }
            break
        }
    }

    function _toTime(n) {
        n = Math.round(n)
        var h = Math.floor(n / 3600)
        n = n - 3600 * h
        var m = Math.floor(n / 60)
        n = n - 60 * m
        var s = Math.floor(n)

        var result = ""
        if (h > 0) {
            result = (h < 10 ? ("0" + h.toString()) : h.toString()) + ":"
        }

        result = result + (m < 10 ? ("0" + m.toString()) : m.toString()) + ":"
        result = result + (s < 10 ? ("0" + s.toString()) : s.toString())
        return result
    }

    function _seek(position) {
        _forceBusyIndicator = true
        console.debug("_forceBusyIndicator=true")
        busyTimer.running = false
        busyTimer.running = true
        mediaplayer.seek(position)
    }

    function _play(url) {
        settingPlaybackOffset.value = 0
        settingPlaybackRowId.value = -1
        settingPlaybackUrl.value = url
        _forceShowMenu = false
        source = url
    }
}

