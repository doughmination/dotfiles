/* lock/shell.qml */

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    // Palette and metrics originally mirrored from the old hyprlock config
    readonly property color signTeal: "#1AC5B0"
    readonly property color signPink: "#E455AE"
    readonly property color textWhite: "#E8FBFD"
    readonly property color failRed: "#FB3048"

    readonly property string fontFamily: "Pixelify Sans"
    readonly property string backgroundPath: "/home/iuse/.config/quickshell/lock/nightcity.png"

    property var currentDate: new Date()
    property string fullName: ""
    property bool failed: false

    // Lives at root because PamContext cannot see ids inside the surface Component
    property string passwordBuffer: ""
    property string fingerprintStatus: "SCAN BIOMETRICS"

    // Stops a broken reader from respawning fprintd-verify forever
    property int fingerprintErrors: 0

    function releaseLock() {
        fingerprintProcess.running = false
        retryTimer.stop()
        sessionLock.locked = false
    }

    Timer {
        running: true
        repeat: true
        interval: 1000
        triggeredOnStart: true

        onTriggered: root.currentDate = new Date()
    }

    Process {
        running: true

        command: [
            "sh",
            "-c",
            "getent passwd \"$(id -un)\" | cut -d: -f5 | cut -d, -f1"
        ]

        stdout: StdioCollector {
            onStreamFinished: root.fullName = text.trim().toUpperCase()
        }
    }

    // Fingerprint runs alongside PAM, the way hyprlock drives fprintd itself
    Process {
        id: fingerprintProcess

        running: true
        command: [ "fprintd-verify" ]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("verify-match")) {
                    root.releaseLock()
                    return
                }

                if (text.includes("verify-no-match")) {
                    root.fingerprintErrors = 0
                    root.fingerprintStatus = "NO MATCH - RETRY"
                } else {
                    root.fingerprintErrors += 1
                }

                if (root.fingerprintErrors < 3) {
                    retryTimer.start()
                } else {
                    root.fingerprintStatus = "BIOMETRICS OFFLINE"
                }
            }
        }
    }

    // hyprlock's retry_delay = 250
    Timer {
        id: retryTimer

        interval: 250
        repeat: false

        onTriggered: fingerprintProcess.running = true
    }

    PamContext {
        id: pam

        config: "quickshell-lock"

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root.passwordBuffer)
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.releaseLock()
            } else {
                root.failed = true
                root.passwordBuffer = ""
            }
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: true

        onLockedChanged: {
            if (!locked) {
                quitTimer.start()
            }
        }

        surface: WlSessionLockSurface {
            id: surface

            color: "#040A10"

            // hyprlock's geometry was tuned at 1080p
            readonly property real scaleFactor: height / 1080

            Image {
                anchors.fill: parent

                source: "file://" + root.backgroundPath
                fillMode: Image.PreserveAspectCrop

                asynchronous: false
                cache: true
            }

            // CLOCK - HOURS
            Text {
                x: 84 * surface.scaleFactor
                y: 84 * surface.scaleFactor

                text: {
                    const hours = root.currentDate.getHours() % 12
                    return String(hours === 0 ? 12 : hours).padStart(2, "0")
                }

                color: "#FFFFFF"

                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: 141 * surface.scaleFactor
                font.letterSpacing: -7 * surface.scaleFactor
            }

            // CLOCK - NEON NEEDLE
            Rectangle {
                x: 275 * surface.scaleFactor
                y: 113 * surface.scaleFactor

                width: 6 * surface.scaleFactor
                height: 113 * surface.scaleFactor

                color: root.signPink
            }

            // CLOCK - MINUTES
            Text {
                x: 309 * surface.scaleFactor
                y: 84 * surface.scaleFactor

                text: String(root.currentDate.getMinutes()).padStart(2, "0")

                color: root.signTeal

                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: 141 * surface.scaleFactor
                font.letterSpacing: -7 * surface.scaleFactor
            }

            // CLOCK - AM/PM
            Text {
                x: 520 * surface.scaleFactor
                y: 200 * surface.scaleFactor

                text: root.currentDate.getHours() < 12 ? "AM" : "PM"

                color: root.textWhite

                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: 40 * surface.scaleFactor
                font.letterSpacing: 2 * surface.scaleFactor
            }

            // DATE
            Text {
                x: 84 * surface.scaleFactor
                y: 268 * surface.scaleFactor

                text: Qt.formatDateTime(
                    root.currentDate,
                    "dddd, MMMM d"
                ).toUpperCase()

                color: "#CCFFFFFF"

                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: 17 * surface.scaleFactor
                font.letterSpacing: 11 * surface.scaleFactor
            }

            // USER NAME
            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                y: parent.height - 277 * surface.scaleFactor - height

                text: root.fullName

                color: root.textWhite

                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: 31 * surface.scaleFactor
                font.letterSpacing: 8.25 * surface.scaleFactor
            }

            // INPUT FIELD
            Item {
                id: inputField

                anchors.horizontalCenter: parent.horizontalCenter

                y: parent.height - 235 * surface.scaleFactor

                width: 506 * surface.scaleFactor
                height: 56 * surface.scaleFactor

                TextInput {
                    id: passwordInput

                    anchors.fill: parent

                    focus: true

                    echoMode: TextInput.Password
                    passwordCharacter: "─"
                    passwordMaskDelay: 0

                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter

                    color: root.signPink

                    font.family: root.fontFamily
                    font.bold: true
                    font.pixelSize: 20 * surface.scaleFactor
                    font.letterSpacing: 17 * surface.scaleFactor

                    text: root.passwordBuffer

                    onTextEdited: {
                        root.passwordBuffer = text
                        root.failed = false
                    }

                    onAccepted: {
                        if (root.passwordBuffer.length > 0 && !pam.active) {
                            pam.start()
                        }
                    }
                }

                // PLACEHOLDER
                Text {
                    anchors.centerIn: parent

                    visible: root.passwordBuffer.length === 0 && !root.failed

                    text: "CONNECTING..."

                    color: Qt.rgba(
                        root.signTeal.r,
                        root.signTeal.g,
                        root.signTeal.b,
                        0.35
                    )

                    font.family: root.fontFamily
                    font.bold: true
                    font.pixelSize: 20 * surface.scaleFactor
                    font.letterSpacing: 5.5 * surface.scaleFactor
                }

                // FAIL TEXT
                Text {
                    anchors.centerIn: parent

                    visible: root.failed

                    text: "PERMISSION DENIED"

                    color: root.failRed

                    font.family: root.fontFamily
                    font.bold: true
                    font.pixelSize: 20 * surface.scaleFactor
                    font.letterSpacing: 4 * surface.scaleFactor
                }
            }

            // INPUT FIELD UNDERLINE
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter

                y: parent.height - 179 * surface.scaleFactor

                width: 506 * surface.scaleFactor
                height: 3 * surface.scaleFactor

                color: root.signPink
            }

            // FINGERPRINT STATUS
            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                y: parent.height - 130 * surface.scaleFactor

                text: root.fingerprintStatus

                color: Qt.rgba(
                    root.signTeal.r,
                    root.signTeal.g,
                    root.signTeal.b,
                    0.55
                )

                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: 15 * surface.scaleFactor
                font.letterSpacing: 5.5 * surface.scaleFactor
            }
        }
    }

    Timer {
        id: quitTimer

        interval: 100
        repeat: false

        onTriggered: Qt.quit()
    }
}
