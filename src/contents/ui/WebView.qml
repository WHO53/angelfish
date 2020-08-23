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
import QtQuick.Controls 2.4 as Controls
import QtQuick.Window 2.1
import QtQuick.Layouts 1.3
import QtWebEngine 1.10

import org.kde.kirigami 2.4 as Kirigami
import org.kde.mobile.angelfish 1.0


WebEngineView {
    id: webEngineView

    property string errorCode: ""
    property string errorString: ""

    property bool privateMode: false

    property alias userAgent: userAgent

    // loadingActive property is set to true when loading is started
    // and turned to false only after succesful or failed loading. It
    // is possible to set it to false by calling stopLoading method.
    //
    // The property was introduced as it triggers visibility of the webEngineView
    // in the other parts of the code. When using loading that is linked
    // to visibility, stop/start loading was observed in some conditions. It looked as if
    // there is an internal optimization of webengine in the case of parallel
    // loading of several pages that could use visibility as one of the decision
    // making parameters.
    property bool loadingActive: false

    property bool reloadOnVisible: true

    // URL that was requested and should be used
    // as a base for user interaction. It reflects
    // last request (successful or failed)
    property url requestedUrl: url

    property int findInPageResultIndex
    property int findInPageResultCount

    // Menu that can be overriden from subclasses
    property Controls.Menu contextMenu: Controls.Menu {
        property ContextMenuRequest request

        Controls.MenuItem {
            enabled: contextMenu.request && (contextMenu.request.editFlags & ContextMenuRequest.CanCopy) != 0
            text: i18n("Copy")
            onTriggered: webEngineView.triggerWebAction(WebEngineView.Copy)
        }
        Controls.MenuItem {
            enabled: contextMenu.request && (contextMenu.request.editFlags & ContextMenuRequest.CanCut) != 0
            text: i18n("Cut")
            onTriggered: webEngineView.triggerWebAction(WebEngineView.Cut)
        }
        Controls.MenuItem {
            enabled: contextMenu.request && (contextMenu.request.editFlags & ContextMenuRequest.CanPaste) != 0
            text: i18n("Paste")
            onTriggered: webEngineView.triggerWebAction(WebEngineView.Paste)
        }
        Controls.MenuItem {
            enabled: contextMenu.request && contextMenu.request.selectedText
            text: contextMenu.request && contextMenu.request.selectedText ? i18n("Search online for '%1'", contextMenu.request.selectedText) : i18n("Search online")
            onTriggered: tabsModel.newTab(UrlUtils.urlFromUserInput(Settings.searchBaseUrl + contextMenu.request.selectedText));
        }
        Controls.MenuItem {
            enabled: contextMenu.request && contextMenu.request.linkUrl !== ""
            text: i18n("Copy Url")
            onTriggered: webEngineView.triggerWebAction(WebEngineView.CopyLinkToClipboard)
        }
        Controls.MenuItem {
            text: i18n("View source")
            onTriggered: tabsModel.newTab("view-source:" + webEngineView.url)
        }
        Controls.MenuItem {
            text: i18n("Download")
            onTriggered: webEngineView.triggerWebAction(WebEngineView.DownloadLinkToDisk)
        }
        Controls.MenuItem {
            enabled: contextMenu.request && contextMenu.request.linkUrl !== ""
            text: i18n("Open in new Tab")
            onTriggered: webEngineView.triggerWebAction(WebEngineView.OpenLinkInNewTab)
        }
    }


    UserAgentGenerator {
        id: userAgent
        onUserAgentChanged: webEngineView.reload()
    }

    settings {
        autoLoadImages: Settings.webAutoLoadImages
        javascriptEnabled: Settings.webJavaScriptEnabled
        // Disable builtin error pages in favor of our own
        errorPageEnabled: false
        // Load larger touch icons
        touchIconsEnabled: true
        // Disable scrollbars on mobile
        showScrollBars: false
    }

    focus: true
    onLoadingChanged: {
        //print("Loading: " + loading);
        print("    url: " + loadRequest.url)
        //print("   icon: " + webEngineView.icon)
        //print("  title: " + webEngineView.title)

        /* Handle
        *  - WebEngineView::LoadStartedStatus,
        *  - WebEngineView::LoadStoppedStatus,
        *  - WebEngineView::LoadSucceededStatus and
        *  - WebEngineView::LoadFailedStatus
        */
        var ec = "";
        var es = "";
        if (loadRequest.status === WebEngineView.LoadStartedStatus) {
            loadingActive = true;
        }
        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
            if (!privateMode) {
                var request = {
                    url: currentWebView.url,
                    title: currentWebView.title,
                    icon: currentWebView.icon
                }

                BrowserManager.addToHistory(request);
                BrowserManager.updateLastVisited(currentWebView.url);
            }
            loadingActive = false;
        }
        if (loadRequest.status === WebEngineView.LoadFailedStatus) {
            print("Load failed: " + loadRequest.errorCode + " " + loadRequest.errorString);
            print("Load failed url: " + loadRequest.url + " " + url);
            ec = loadRequest.errorCode;
            es = loadRequest.errorString;
            loadingActive = false;

            // update requested URL only after its clear that it fails.
            // Otherwise, its updated as a part of url property update.
            if (requestedUrl !== loadRequest.url)
                requestedUrl = loadRequest.url;
        }
        errorCode = ec;
        errorString = es;
    }

    Component.onCompleted: {
        print("WebView completed.");
        print("Settings: " + webEngineView.settings);
    }

    onIconChanged: {
        if (icon && !privateMode)
            BrowserManager.updateIcon(url, icon)
    }

    onNewViewRequested: {
        if (request.userInitiated) {
            tabsModel.newTab(request.requestedUrl.toString())
            showPassiveNotification(i18n("Website was opened in a new tab"))
        } else {
            questionLoader.setSource("NewTabQuestion.qml")
            questionLoader.item.url = request.requestedUrl
            questionLoader.item.visible = true
        }
    }

    onUrlChanged: {
        if (requestedUrl !== url) {
            requestedUrl = url;
        }
    }

    onFullScreenRequested: {
        request.accept()
        if (webBrowser.visibility !== Window.FullScreen)
            webBrowser.showFullScreen()
        else
            webBrowser.showNormal()
    }

    onContextMenuRequested: {
        request.accepted = true // Make sure QtWebEngine doesn't show its own context menu.
        contextMenu.request = request
        contextMenu.x = request.x
        contextMenu.y = request.y
        contextMenu.open()
    }

    onAuthenticationDialogRequested: {
        request.accepted = true
        sheetLoader.setSource("AuthSheet.qml")
        sheetLoader.item.request = request
        sheetLoader.item.open()
    }

    onFeaturePermissionRequested: {
        questionLoader.setSource("PermissionQuestion.qml")
        questionLoader.item.permission = feature
        questionLoader.item.origin = securityOrigin
        questionLoader.item.visible = true
    }

    onJavaScriptDialogRequested: {
        request.accepted = true
        sheetLoader.setSource("JavaScriptDialogSheet.qml")
        sheetLoader.item.request = request
        sheetLoader.item.open()
    }

    onFindTextFinished: {
        findInPageResultIndex = result.activeMatch;
        findInPageResultCount = result.numberOfMatches;
    }

    onVisibleChanged: {
        // set user agent to the current displayed tab
        // this ensures that we follow mobile preference
        // of the current webview. also update the current
        // snapshot image with short delay to be sure that
        // all kirigami pages have moved into place
        if (visible) {
            profile.httpUserAgent = Qt.binding(function() { return userAgent.userAgent; });
            if (reloadOnVisible) {
                reloadOnVisible = false;
                reload();
            }
        }
    }

    function findInPageBack(text) {
        findText(text, WebEngineView.FindBackward);
    }

    function findInPageForward(text) {
        findText(text);
    }

    function stopLoading() {
        loadingActive = false;
        stop();
    }
}
