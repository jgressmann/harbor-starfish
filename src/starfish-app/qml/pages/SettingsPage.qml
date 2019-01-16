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
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import org.duckdns.jgressmann 1.0
import ".."


BasePage {
    id: root
    showProgressPanel: false
    property string _currentdataDirectory
    property string _targetdataDirectory
    readonly property bool _toolEnabled: !VodDataManager.busy

    Component.onDestruction: {
        settings.sync()
    }

    Component.onCompleted: {
        _currentdataDirectory = VodDataManager.dataDirectory
        _targetdataDirectory = _currentdataDirectory
    }

    onStatusChanged: {
        switch (status) {
        case PageStatus.Activating:
            _currentdataDirectory = VodDataManager.dataDirectory
            break
        }
    }

    Component {
        id: confirmMovePage
        Dialog {

            DialogHeader {
                id: dialogHeader
                title: "Confirm data directory move"
                acceptText: "Move"
            }

            Label {
                color: Theme.highlightColor
                anchors.top: dialogHeader.bottom
                anchors.bottom: parent.bottom
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                wrapMode: Text.Wrap
                text:
"The application's data will be moved to " + _targetdataDirectory + ".

This operation could take a good long while. During this time you will not be able to use the application.

Do you want to continue?"
            }

            // page is created prior to onAccepted, see api reference doc
            acceptDestination: Qt.resolvedUrl("MoveDataDirectoryPage.qml")
            acceptDestinationAction: PageStackAction.Replace
            acceptDestinationProperties: {
                "targetDirectory": _targetdataDirectory
            }


            onAccepted: {
                VodDataManager.moveDataDirectory(_targetdataDirectory)
//                pageStack.replace(
//                            Qt.resolvedUrl("MoveDataDirectoryPage.qml"),
//                            {
//                                "targetDirectory": _targetdataDirectory
//                            },
//                            PageStackAction.Immediate)
            }

        }
    }

    Component {
        id: filePickerPage
        FilePickerPage {
            //nameFilters: [ '*.pdf', '*.doc' ]
            nameFilters: []
            onSelectedContentPropertiesChanged: {
                _targetdataDirectory = saveDirectoryTextField.text = _getDirectory(selectedContentProperties.filePath)
            }
        }
    }

    VisualItemModel {
        id: model

        SectionHeader {
            text: "Data"
        }


        ComboBox {
            id: saveDirectoryComboBox
            width: root.width
            label: "Directory"
            enabled: _toolEnabled
            menu: ContextMenu {
                MenuItem { text: "Cache" }
                MenuItem { text: "Custom" }
            }
        }

        TextField {
            id: saveDirectoryTextField
            width: root.width
            text: _currentdataDirectory
            label: "Directory for VOD and meta data"
            placeholderText: "Data directory"
            EnterKey.iconSource: "image://theme/icon-m-enter-close"
            EnterKey.onClicked: focus = false
            enabled: _toolEnabled

            Component.onCompleted: {
                // combobox initially has index 0 which may be wrong
                _onSaveDirectoryTextFieldTextChanged()
            }
        }

        ButtonLayout {
            width: root.width
//            spacing: Theme.paddingSmall

            Button {
//                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pick directory"
                enabled: _toolEnabled
                onClicked: pageStack.push(filePickerPage)
            }

            Button {
                enabled: _toolEnabled && !!_targetdataDirectory &&
                         _currentdataDirectory !== _targetdataDirectory
//                anchors.horizontalCenter: parent.horizontalCenter
                text: "Apply change"
                onClicked: pageStack.push(confirmMovePage)
            }
        }

        SectionHeader {
            text: "Network"
        }

        ComboBox {
            id: bearerModeComboBox
            width: root.width
            label: "Network connection type"
            menu: ContextMenu {
                MenuItem { text: "Autodetect" }
                MenuItem { text: "Broadband" }
                MenuItem { text: "Mobile" }
            }

            Component.onCompleted: currentIndex = settingBearerMode.value

            onCurrentIndexChanged: {
                console.debug("bearer mode onCurrentIndexChanged " + currentIndex)
                settingBearerMode.value = currentIndex
            }
        }

        TextField {
            width: root.width
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            label: "Max concurrent meta data downloads"
            text: settingNetworkMaxConcurrentMetaDataDownloads.value.toFixed(0)
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: focus = false
            enabled: _toolEnabled
            validator: IntValidator {
                bottom: 1
            }

            onTextChanged: {
                console.debug("text: " + text)
                if (acceptableInput) {
                    var number = parseFloat(text)
                    console.debug("number: " + number)
                    if (typeof(number) === "number") {
                        settingNetworkMaxConcurrentMetaDataDownloads.value = number
                    }
                }
            }
        }

        ComboBox {
            width: root.width
            label: "VOD site"
            description: "This site is used to check for new VODs."
            enabled: _toolEnabled
            menu: ContextMenu {
                id: menu
                MenuItem { text: "sc2casts.com" }
                MenuItem { text: "sc2links.com" }
            }

            Component.onCompleted: {
                if (sc2CastsDotComScraper.id === settingNetworkScraper.value) {
                    currentIndex = 0
                } else {
                    currentIndex = 1
                }
            }

            onCurrentIndexChanged: {
                switch (currentIndex) {
                case 0:
                    settingNetworkScraper.value = sc2CastsDotComScraper.id
                    break
                case 1:
                    settingNetworkScraper.value = sc2LinksDotComScraper.id
                    break
                }
            }
        }

        TextSwitch {

            text: "Periodically check for new VODs"
            checked: settingNetworkAutoUpdate.value
            enabled: _toolEnabled
            onCheckedChanged: {
                console.debug("auto update=" + checked)
                settingNetworkAutoUpdate.value = checked
            }
        }

        TextField {
            enabled: _toolEnabled && settingNetworkAutoUpdate.value
            width: root.width
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            label: "Minutes between checks"
            text: settingNetworkAutoUpdateIntervalM.value.toFixed(0)
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: focus = false
            validator: IntValidator {
                bottom: debugApp.value ? 1 : 10
            }

            onTextChanged: {
                console.debug("text: " + text)
                if (acceptableInput) {
                    var number = parseInt(text)
                    console.debug("number: " + number)
                    if (typeof(number) === "number" && number >= validator.bottom) {
                        settingNetworkAutoUpdateIntervalM.value = number
                    }
                }
            }
        }

        TextSwitch {
            text: "Continue VOD file download when page closes"
            checked: settingNetworkContinueDownload.value
            enabled: _toolEnabled
            onCheckedChanged: {
                console.debug("continue download=" + checked)
                settingNetworkContinueDownload.value = checked
            }
        }


        SectionHeader {
            text: "Format"
        }

        FormatComboBox {
            width: root.width
            label: "Broadband"
            excludeAskEveryTime: false
            format: settingBroadbandDefaultFormat.value
            enabled: _toolEnabled
            onFormatChanged: {
//                console.debug("save")
                settingBroadbandDefaultFormat.value = format
            }
        }

        FormatComboBox {
            width: root.width
            label: "Mobile"
            excludeAskEveryTime: false
            format: settingMobileDefaultFormat.value
            enabled: _toolEnabled
            onFormatChanged: {
//                console.debug("save")
                settingMobileDefaultFormat.value = format
            }
        }

        SectionHeader {
            text: "Playback"
        }

        TextSwitch {
            text: "Use external media player"
            checked: settingExternalMediaPlayer.value
            enabled: _toolEnabled
            onCheckedChanged: {
                console.debug("external media player=" + checked)
                settingExternalMediaPlayer.value = checked
            }
        }

        TextField {
            width: root.width
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            label: "Number of recently watched videos to keep"
            text: settingPlaybackRecentVideosToKeep.value.toFixed(0)
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: focus = false
            enabled: _toolEnabled
            validator: IntValidator {
                bottom: 1
            }

            onTextChanged: {
                console.debug("text: " + text)
                if (acceptableInput) {
                    var number = parseFloat(text)
                    console.debug("number: " + number)
                    if (typeof(number) === "number") {
                        settingPlaybackRecentVideosToKeep.value = number
                    }
                }
            }
        }

        TextSwitch {
            text: "Pause playback on device lock"
            checked: settingPlaybackPauseOnDeviceLock.value
            enabled: _toolEnabled
            onCheckedChanged: {
                console.debug("continue playback on device lock=" + checked)
                settingPlaybackPauseOnDeviceLock.value = checked
            }
        }

        TextSwitch {
            text: "Pause playback when the cover page is shown"
            checked: settingPlaybackPauseInCoverMode.value
            enabled: _toolEnabled
            onCheckedChanged: {
                console.debug("continue playback in cover mode=" + checked)
                settingPlaybackPauseInCoverMode.value = checked
            }
        }

        SectionHeader {
            text: "New"
        }

        TextField {
            width: root.width
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            label: "Number of days to keep a VOD in 'New'"
            text: settingNewWindowDays.value.toFixed(0)
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: focus = false
            enabled: _toolEnabled
            validator: IntValidator {
                bottom: 1
            }

            onTextChanged: {
                console.debug("text: " + text)
                if (acceptableInput) {
                    var number = parseFloat(text)
                    console.debug("number: " + number)
                    if (typeof(number) === "number") {
                        settingNewWindowDays.value = number
                    }
                }
            }
        }

        TextSwitch {
            text: "Remove watched VODs from 'New'"
            checked: settingNewRemoveSeen.value
            enabled: _toolEnabled
            onCheckedChanged: {
                console.debug("remove seen vods from new=" + checked)
                settingNewRemoveSeen.value = checked
            }
        }

    }

    contentItem: SilicaFlickable {
        anchors.fill: parent
        contentWidth: parent.width

        VerticalScrollDecorator {}

        SilicaListView {
            id: listView
            anchors.fill: parent
            model: model
            header: PageHeader {
                title: "Settings"
                VodDataManagerBusyIndicator {}
            }
        }
    }

    Connections {
        id: saveDirectoryComboBoxConnections
        target: saveDirectoryComboBox
        onCurrentIndexChanged: {
            saveDirectoryTextFieldConnections.target = null
            _updateSaveDirectoryTextField()
            saveDirectoryTextFieldConnections.target = saveDirectoryTextField
        }
    }

    Connections {
        id: saveDirectoryTextFieldConnections
        target: saveDirectoryTextField
        onTextChanged: _onSaveDirectoryTextFieldTextChanged()
    }

    function _getDirectory(str) {
        var lastSlashIndex = str.lastIndexOf("/")
        if (lastSlashIndex > 0) {
            str = str.substr(0, lastSlashIndex);
        }

        return str
    }

    function _updateSaveDirectoryComboBox() {
        _targetdataDirectory = saveDirectoryTextField.text
        if (saveDirectoryTextField.text === StandardPaths.cache) {
            saveDirectoryComboBox.currentIndex = 0
//        } else if (settingDefaultDirectory.value === StandardPaths.videos) {
//            saveDirectoryComboBox.currentIndex = 1
        } else {
            saveDirectoryComboBox.currentIndex = 1
        }
    }

    function _onSaveDirectoryTextFieldTextChanged() {
        saveDirectoryComboBoxConnections.target = null
        _updateSaveDirectoryComboBox()
        saveDirectoryComboBoxConnections.target = saveDirectoryComboBox
    }

    function _updateSaveDirectoryTextField() {
        switch (saveDirectoryComboBox.currentIndex) {
        case 0:
            _targetdataDirectory = saveDirectoryTextField.text = StandardPaths.cache
            break
        default:
            //pageStack.push(filePickerPage)
            break
        }
    }

}

