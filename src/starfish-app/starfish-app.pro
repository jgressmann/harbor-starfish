# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-starfish

CONFIG += sailfishapp


SOURCES += harbour-starfish.cpp \
    SqlVodModel.cpp \
    ScVodman.cpp \
    ScApp.cpp \
    ScVodDataManager.cpp \
    ScVodDatabaseDownloader.cpp \
    ScIcons.cpp



HEADERS += \
    SqlVodModel.h \
    ScVodman.h \
    ScApp.h \
    ScVodDataManager.h \
    ScVodDatabaseDownloader.h \
    ScIcons.h

#../../rpm/harbour-starfish.changes.run.in \
#../../rpm/harbour-starfish.yaml \
#    ../../rpm/harbour-starfish.changes.in \
#    ../../rpm/harbour-starfish.spec \
#translations/*.ts \


DISTFILES += qml/harbour-starfish.qml \
    qml/cover/CoverPage.qml \
    harbour-starfish.desktop \
    media/*.png \
    icons.json \
    qml/pages/StartPage.qml \
    qml/pages/FilterItem.qml \
    qml/pages/FilterPage.qml \
    qml/pages/SelectionPage.qml \
    qml/Global.qml \
    qml/qmldir \
    qml/pages/TournamentPage.qml \
    qml/pages/StageItem.qml \
    qml/pages/MatchItem.qml \
    qml/pages/StagePage.qml \
    qml/pages/VideoPlayerPage.qml \
    qml/pages/BasePage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/SelectFormatDialog.qml \
    qml/pages/NewPage.qml \
    qml/pages/EntryPage.qml \
    qml/pages/AboutPage.qml \
    qml/TopMenu.qml \
    qml/Global.qml \
    qml/FormatComboBox.qml \
    qml/ProgressOverlay.qml \
    qml/SeenButton.qml \
    qml/ProgressMaskEffect.qml \
    qml/ProgressImageBlendEffect.qml

DEFINES += SAILFISH_DATADIR="/usr/share/$${TARGET}"

media.path = /usr/share/$${TARGET}/media
media.files = media/sc2.png media/bw.png
INSTALLS += media

xml.path = /usr/share/$${TARGET}/xml
xml.files = xml/*
INSTALLS += xml

gzicons.target = icons.json.gz
#gzicons.path = /usr/share/$${TARGET}/$$xicons.target
gzicons.commands = cat $$PWD/icons.json | gzip --best > $$PWD/$$gzicons.target

QMAKE_EXTRA_TARGETS += gzicons

icons.files = $$gzicons.target
icons.path = /usr/share/$${TARGET}
icons.depends = gzicons
INSTALLS += icons





SAILFISHAPP_ICONS = 86x86 108x108 128x128 256x256

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
#TRANSLATIONS += translations/harbour-starfish-de.ts

DBUS_INTERFACES += /usr/share/dbus-1/interfaces/org.duckdns.jgressmann.vodman.service.xml


QT *= network sql qml xml dbus





CONFIG *= link_pkgconfig
PKGCONFIG += sailfishapp
LIBS += -lvodman
#LIBS += -L../starfish-lib -lstarfish
LIBS += -lz



include(../../common.pri)
include(../starfish-lib/src.pri)

