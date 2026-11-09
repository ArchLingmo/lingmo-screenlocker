/*
 * SPDX-FileCopyrightText: 2021 Rion Wong <reionwong@gmail.com>
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// Lingmo lock screen for KWin's screen locker (kscreenlocker_greet 6.8), used by
// the Wayland session. Same look as lingmo-screenlocker (X11) and the SDDM theme.
//
// The greeter gives us these context properties:
//   authenticator            PamAuthenticators (startAuthenticating, respond, ...)
//   kscreenlocker_userName   full name (or login name)
//   kscreenlocker_userImage  path of the user's face icon, may be empty
//   wallpaper                KDE's wallpaper plugin item (hidden: we draw our own)
//
// How 6.8 authenticates: startAuthenticating() asks the PAM worker to run
// pam_authenticate; when PAM wants the password, promptForSecretChanged fires and
// the worker waits until respond(password). The reply has to be sent after that
// signal handler returns (the greeter stores the pending prompt only afterwards),
// so it always goes through Qt.callLater. The worker may not be up when the lock
// screen shows, so a heartbeat keeps asking until a prompt is pending.

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Lingmo.System 1.0 as System
import LingmoUI.CompatibleModule 3.0 as LingmoUI

Item {
    id: root

    // Written by the greeter
    property bool viewVisible: false
    property bool locked: true

    property string notification

    // A PAM prompt waits for respond()
    property bool promptPending: false
    // respond() was sent, the result (succeeded/failed) has not come yet
    property bool waitingResult: false
    // typed before the worker asked for it
    property string pendingPassword
    // PAM's delay after a failed attempt (the greeter's inPasswordDelay has no
    // working change signal in 6.8, so it is tracked here)
    property bool inDelay: false

    readonly property string domain: "lingmo-lockscreen"
    readonly property bool fingerprintAvailable: (authenticator.authenticatorTypes & 1) !== 0

    implicitWidth: 800
    implicitHeight: 600

    LayoutMirroring.enabled: Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    function showMessage(text) {
        root.notification = text
        notificationResetTimer.restart()
    }

    function submit() {
        if (authenticator.unlocked || root.waitingResult || root.inDelay)
            return

        if (password.text === "") {
            root.showMessage(i18nd(root.domain, "Please enter your password"))
            return
        }

        if (root.promptPending) {
            root.respondWith(password.text)
        } else {
            // The worker is not asking yet: answer as soon as it does
            root.pendingPassword = password.text
            authenticator.startAuthenticating()
        }
    }

    function respondWith(text) {
        root.promptPending = false
        root.waitingResult = true
        root.pendingPassword = ""
        resultTimeout.restart()
        authenticator.respond(text)
    }

    function respondPending() {
        if (root.promptPending && root.pendingPassword !== "")
            root.respondWith(root.pendingPassword)
    }

    function resetFocus() {
        password.forceActiveFocus()
    }

    onViewVisibleChanged: {
        if (viewVisible) {
            blurAni.start()
            resetFocus()
        }
    }

    Component.onCompleted: {
        // KDE's wallpaper plugin is stacked under this item; draw only ours
        if (typeof wallpaper !== "undefined" && wallpaper)
            wallpaper.visible = false

        timeLabel.updateInfo()
        dateLabel.updateInfo()
        resetFocus()
    }

    System.Wallpaper {
        id: lingmoWallpaper
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: "file://" + (lingmoWallpaper.path || "/usr/share/backgrounds/lingmoos/default.jpg")
        sourceSize: Qt.size(width * Screen.devicePixelRatio,
                            height * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        clip: true
        cache: false
        smooth: true
        visible: false
    }

    FastBlur {
        id: wallpaperBlur
        anchors.fill: parent
        radius: 64
        source: wallpaperImage
        cached: true
    }

    NumberAnimation {
        id: blurAni
        target: wallpaperBlur
        property: "radius"
        duration: 300
        from: 10
        to: 64
    }

    Timer {
        repeat: true
        running: true
        interval: 1000

        onTriggered: {
            timeLabel.updateInfo()
            dateLabel.updateInfo()
        }
    }

    // Heartbeat: (re)start the PAM conversation until the worker asks for the
    // password. Only in the window that has the keyboard, so several screens
    // don't start several conversations.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.viewVisible && root.Window.active && !authenticator.unlocked
                 && !root.promptPending && !root.waitingResult
                 && !authenticator.busy && !root.inDelay
        onTriggered: authenticator.startAuthenticating()
    }

    // Never stay stuck waiting for a result that does not come (PAM unavailable)
    Timer {
        id: resultTimeout
        interval: 20000
        onTriggered: root.waitingResult = false
    }

    Timer {
        id: delayTimer
        onTriggered: root.inDelay = false
    }

    Timer {
        id: notificationResetTimer
        interval: 3000
        onTriggered: root.notification = ""
    }

    Item {
        id: _topItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: _mainItem.top
        anchors.bottomMargin: root.height * 0.1

        Label {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            font.pointSize: 35
            color: "white"

            function updateInfo() {
                timeLabel.text = new Date().toLocaleString(Qt.locale(), "hh:mm")
            }
        }

        Label {
            id: dateLabel
            anchors.top: timeLabel.bottom
            anchors.topMargin: LingmoUI.Units.largeSpacing
            anchors.horizontalCenter: parent.horizontalCenter
            font.pointSize: 19
            color: "white"

            function updateInfo() {
                dateLabel.text = new Date().toLocaleDateString(Qt.locale(), Locale.LongFormat)
            }
        }

        DropShadow {
            anchors.fill: timeLabel
            source: timeLabel
            z: -1
            horizontalOffset: 1
            verticalOffset: 1
            radius: 10
            samples: radius * 4
            spread: 0.35
            color: Qt.rgba(0, 0, 0, 0.8)
            opacity: 0.1
        }

        DropShadow {
            anchors.fill: dateLabel
            source: dateLabel
            z: -1
            horizontalOffset: 1
            verticalOffset: 1
            radius: 10
            samples: radius * 4
            spread: 0.35
            color: Qt.rgba(0, 0, 0, 0.8)
            opacity: 0.1
        }
    }

    Item {
        id: _mainItem
        anchors.centerIn: parent
        width: 280 + LingmoUI.Units.largeSpacing * 3
        height: _mainLayout.implicitHeight + LingmoUI.Units.largeSpacing * 4

        transform: Translate { id: shakeTranslate }

        GlassPanel {
            anchors.fill: parent
        }

        ColumnLayout {
            id: _mainLayout
            anchors.fill: parent
            anchors.margins: LingmoUI.Units.largeSpacing * 1.5
            spacing: LingmoUI.Units.smallSpacing * 1.5

            Item {
                id: avatar

                property int iconSize: 60

                Layout.preferredWidth: iconSize
                Layout.preferredHeight: iconSize
                Layout.alignment: Qt.AlignHCenter

                // No face icon: the first letter of the name on the accent color
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: LingmoUI.Theme.highlightColor
                    visible: userIcon.status !== Image.Ready

                    Label {
                        anchors.centerIn: parent
                        text: kscreenlocker_userName.length > 0 ? kscreenlocker_userName.charAt(0).toUpperCase() : ""
                        font.pointSize: 22
                        color: "white"
                    }
                }

                Image {
                    id: userIcon
                    anchors.fill: parent
                    source: kscreenlocker_userImage ? "file://" + kscreenlocker_userImage : ""
                    sourceSize: Qt.size(avatar.iconSize * Screen.devicePixelRatio,
                                        avatar.iconSize * Screen.devicePixelRatio)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: status === Image.Ready

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Item {
                            width: userIcon.width
                            height: userIcon.height

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.height / 2
                            }
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: _mainLayout.width
                elide: Text.ElideRight
                text: kscreenlocker_userName
            }

            Item {
                height: 1
            }

            TextField {
                id: password
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 36
                Layout.fillWidth: true
                placeholderText: i18nd(root.domain, "Password")
                leftPadding: LingmoUI.Units.largeSpacing
                rightPadding: 36 + LingmoUI.Units.largeSpacing
                enabled: !root.waitingResult && !root.inDelay
                focus: true
                selectByMouse: true
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

                background: Rectangle {
                    color: LingmoUI.Theme.darkMode ? "#B6B6B6" : "white"
                    opacity: 0.5
                }

                Keys.onEnterPressed: root.submit()
                Keys.onReturnPressed: root.submit()

                onEnabledChanged: {
                    if (enabled)
                        root.resetFocus()
                }

                Item {
                    id: unlockButton
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 36

                    Rectangle {
                        id: unlockBackground
                        anchors.fill: parent
                        color: unlockArea.pressed ? Qt.darker(LingmoUI.Theme.highlightColor, 1.2)
                             : unlockArea.containsMouse ? Qt.lighter(LingmoUI.Theme.highlightColor, 1.1)
                             : LingmoUI.Theme.highlightColor

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(unlockBackground.color, 1.3) }
                            GradientStop { position: 1.0; color: unlockBackground.color }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 10
                        source: "images/screensaver-unlock-symbolic.svg"
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: unlockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: password.enabled
                        onClicked: root.submit()
                    }
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: password.width
                        height: password.height

                        Rectangle {
                            anchors.fill: parent
                            radius: LingmoUI.Theme.mediumRadius
                        }
                    }
                }
            }

            // Fingerprint login is on: the finger works without typing anything
            Label {
                visible: root.fingerprintAvailable
                text: i18nd(root.domain, "Touch the fingerprint reader or type your password")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: _mainLayout.width
            }

            Item {
                height: 1
            }
        }
    }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: shakeTranslate; property: "x"; to: -16; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; to: 14; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; to: -10; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; to: 6; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTranslate; property: "x"; to: 0; duration: 50; easing.type: Easing.InQuad }
    }

    Label {
        id: message
        anchors.top: _mainItem.bottom
        anchors.topMargin: LingmoUI.Units.largeSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, root.width - LingmoUI.Units.largeSpacing * 4)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.bold: true
        color: "white"
        text: root.notification

        Behavior on opacity {
            NumberAnimation {
                duration: 250
            }
        }

        opacity: text == "" ? 0 : 1
    }

    DropShadow {
        anchors.fill: message
        source: message
        z: -1
        horizontalOffset: 1
        verticalOffset: 1
        radius: 10
        samples: radius * 4
        spread: 0.35
        color: Qt.rgba(0, 0, 0, 0.8)
        opacity: 0.3
    }

    Connections {
        target: authenticator

        function onPromptForSecretChanged() {
            // Also emitted, empty, when the authenticator is (re)created
            if (!authenticator.hadPrompt)
                return
            root.promptPending = true
            root.waitingResult = false
            if (root.pendingPassword !== "")
                Qt.callLater(root.respondPending)
        }

        function onPromptChanged() {
            if (!authenticator.hadPrompt || authenticator.prompt === "")
                return
            root.promptPending = true
            root.waitingResult = false
            root.showMessage(authenticator.prompt)
        }

        function onFailed(kind) {
            // Non-interactive authenticators (fingerprint) fail on their own
            if (kind != 0)
                return
            resultTimeout.stop()
            root.waitingResult = false
            root.promptPending = false
            root.pendingPassword = ""
            password.text = ""
            root.showMessage(i18nd(root.domain, "Wrong password"))
            shakeAnimation.restart()
            root.resetFocus()
        }

        function onLoginFailedDelayStarted(kind, auth, usec) {
            if (kind != 0 || usec <= 0)
                return
            root.inDelay = true
            delayTimer.interval = Math.max(1, Math.round(usec / 1000))
            delayTimer.restart()
        }

        function onSucceeded() {
            resultTimeout.stop()
            // Stops the other authenticators (fingerprint) before quitting
            authenticator.stopAuthenticating()
            Qt.quit()
        }

        function onInfoMessageChanged() {
            if (authenticator.infoMessage !== "")
                root.showMessage(authenticator.infoMessage)
        }

        function onErrorMessageChanged() {
            if (authenticator.errorMessage !== "")
                root.showMessage(authenticator.errorMessage)
        }
    }
}
