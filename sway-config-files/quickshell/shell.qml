/* shell.qml */

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.I3
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

ShellRoot {
    id: root

    // Cyberpunk palette, mirrored from ~/.config/sway/cyberpunk
    readonly property color colorBase: "#040A10"
    readonly property color colorPink: "#E455AE"
    readonly property color colorYellow: "#FDF500"
    readonly property color colorTeal: "#1AC5B0"
    readonly property color colorFlamingo: "#ED91CA"
    readonly property color colorGreen: "#28C775"
    readonly property color colorText: "#E8FBFD"

    readonly property string fontFamily: "DaddyTimeMono Nerd Font"

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: bar

            required property var modelData

            screen: bar.modelData

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: 15
                left: 13
                right: 13
            }

            implicitHeight: 40

            color: "transparent"

            Rectangle {
                anchors.fill: parent

                radius: 14
                color: Qt.rgba(
                    root.colorBase.r,
                    root.colorBase.g,
                    root.colorBase.b,
                    0.6
                )

                border.color: root.colorPink
                border.width: 2

                // Workspaces
                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16

                    spacing: 10

                    Repeater {
                        model: I3.workspaces

                        delegate: Text {
                            required property var modelData

                            text: modelData.focused ? "" : ""

                            color: modelData.urgent
                                ? root.colorFlamingo
                                : root.colorPink

                            font.family: root.fontFamily
                            font.pixelSize: 14

                            MouseArea {
                                anchors.fill: parent

                                onClicked: I3.dispatch(
                                    "workspace number " + modelData.num
                                )
                            }
                        }
                    }
                }

                // Clock
                Text {
                    id: clock

                    anchors.centerIn: parent

                    color: root.colorText

                    font.family: root.fontFamily
                    font.pixelSize: 16

                    Timer {
                        running: true
                        repeat: true
                        interval: 1000
                        triggeredOnStart: true

                        onTriggered: clock.text = Qt.formatDateTime(
                            new Date(),
                            "hh:mm"
                        )
                    }
                }

                // Volume and battery
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16

                    spacing: 14

                    PwObjectTracker {
                        objects: [ Pipewire.defaultAudioSink ]
                    }

                    Text {
                        readonly property var sink: Pipewire.defaultAudioSink

                        text: sink && sink.audio && sink.audio.muted
                            ? ""
                            : ""

                        color: sink && sink.audio && sink.audio.muted
                            ? root.colorFlamingo
                            : root.colorTeal

                        font.family: root.fontFamily
                        font.pixelSize: 18
                    }

                    Text {
                        readonly property var battery: UPower.displayDevice

                        text: battery
                            ? Math.round(battery.percentage * 100) + "%"
                            : ""

                        color: battery && battery.percentage < 0.2
                            ? root.colorFlamingo
                            : root.colorGreen

                        font.family: root.fontFamily
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}
