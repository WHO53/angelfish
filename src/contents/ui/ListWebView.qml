/***************************************************************************
 *                                                                         *
 *   Copyright 2014-2015 Sebastian Kügler <sebas@kde.org>                  *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 *                                                                         *
 ***************************************************************************/

import QtQuick 2.3
import QtQuick.Controls 2.0
import QtQml.Models 2.1
import QtWebEngine 1.6

import org.kde.kirigami 2.7 as Kirigami
import org.kde.mobile.angelfish 1.0


Repeater {
    id: tabs
    clip: true

    property bool activeTabs: false
    property bool privateTabsMode: false

    property alias currentIndex: tabsModel.currentTab
    property WebView currentItem

    property alias tabsModel: tabsModel

    property WebEngineProfile profile: WebEngineProfile {
        httpUserAgent: tabs.currentItem.userAgent.userAgent
        offTheRecord: tabs.privateTabsMode
        storageName: tabs.privateTabsMode ? "Private" : Settings.profile

        onDownloadRequested: {
            // if we don't accept the request right away, it will be deleted
            download.accept()
            // therefore just stop the download again as quickly as possible,
            // and ask the user for confirmation
            download.pause()

            questionLoader.setSource("DownloadQuestion.qml")
            questionLoader.item.download = download
            questionLoader.item.visible = true
        }

        onDownloadFinished: {
            if (download.state === WebEngineDownloadItem.DownloadCompleted) {
                showPassiveNotification(i18n("Download finished"))
            }
            else if (download.state === WebEngineDownloadItem.DownloadInterrupted) {
                showPassiveNotification(i18n("Download failed"))
                console.log("Download interrupt reason: " + download.interruptReason)
            }
            else if (download.state === WebEngineDownloadItem.DownloadCancelled) {
                console.log("Download cancelled by the user")
            }
        }
    }

    model: TabsModel {
        id: tabsModel
        isMobileDefault: Kirigami.Settings.isMobile
        privateMode: privateTabsMode
        Component.onCompleted: {
            tabsModel.loadInitialTabs();
            loadTabsModel();
        }
        signal loadTabsModel()
    }

    delegate: WebView {
        id: webView
        anchors {
            bottom: tabs.bottom
            top: tabs.top
        }
        privateMode: tabs.privateTabsMode
        userAgent.isMobile: model.isMobile
        width: tabs.width

        profile: tabs.profile

        property bool readyForSnapshot: false
        property bool showView: index === tabs.currentIndex

        visible: (showView || readyForSnapshot || loadingActive) && tabs.activeTabs
        x: showView && tabs.activeTabs ? 0 : -width
        z: showView && tabs.activeTabs ? 0 : -1

        onShowViewChanged: {
            if (showView) {
                tabs.currentItem = webView
            }
        }

        onRequestedUrlChanged: tabsModel.setUrl(index, requestedUrl)

        Component.onCompleted: url = model.pageurl

        Connections {
            target: webView.userAgent
            onUserAgentChanged: {
                tabsModel.setIsMobile(index, webView.userAgent.isMobile);
            }
        }

        Connections {
            target: tabs.model
            onLoadTabsModel: url = model.pageurl
        }
    }
}
