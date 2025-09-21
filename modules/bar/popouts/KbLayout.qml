pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell

Item {
    id: root

    // Layouts with indexes
    // Order matters: must match hyprctl devices -j
    property var layouts: [
        { name: "us", index: 0 },
        { name: "ee", index: 1 },
        { name: "ru", index: 2 }
    ]

    implicitWidth: layout.implicitWidth + Appearance.padding.normal * 2
    implicitHeight: layout.implicitHeight + Appearance.padding.normal * 2

    ButtonGroup { id: layoutsGroup }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Keyboard Layout")
            font.weight: 500
        }

        Repeater {
            model: root.layouts

            StyledRadioButton {
                required property var modelData

                ButtonGroup.group: layoutsGroup
                checked: Hypr.kbLayout === modelData.name
                text: modelData.name

                onClicked: {
                    Quickshell.execDetached([
                        "sh", "-c",
                        `hyprctl switchxkblayout all ${modelData.index}`
                    ])
                }
            }
        }

        StyledText {
            Layout.topMargin: Appearance.spacing.smaller
            text: qsTr("Current: %1").arg(Hypr.kbLayoutFull)
            font.weight: 500
        }
    }
}
