pragma ComponentBehavior: Bound

import qs.services
import qs.config
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    readonly property int vPadding: Appearance.padding.large

    // Helper function to find a WrappedLoader by id
    function getLoader(loaderId) {
        for (let i = 0; i < repeater.count; i++) {
            let item = repeater.itemAt(i);
            if (item && item.id === loaderId)
                return item;
        }
        return null;
    }

    function checkPopout(y: real): void {
        const spacing = Appearance.spacing.small;
        const activeWindowLoader = getLoader("activeWindow");
        const trayLoader = getLoader("tray");
        const clockLoader = getLoader("clock");
        const statusIconsLoader = getLoader("statusIcons");

        // Use .item to access the loaded component inside WrappedLoader
        const aw = activeWindowLoader?.item;
        const awy = activeWindowLoader ? activeWindowLoader.y + (aw?.y ?? 0) : 0;

        const tray = trayLoader?.item;
        const ty = trayLoader ? trayLoader.y : 0;
        const th = trayLoader ? trayLoader.implicitHeight : 0;
        const trayItems = tray?.items;

        const clockY = clockLoader ? clockLoader.y : 0;
        const clockHeight = clockLoader ? clockLoader.implicitHeight : 0;

        let statusIconFound = false;
        const statusIconsInner = statusIconsLoader?.item;
        if (statusIconsInner) {
            for (const area of statusIconsInner.hoverAreas) {
                if (!area.enabled)
                    continue;
                const item = area.item;
                const itemY = statusIconsLoader.y + statusIconsInner.y + item.y - spacing / 2;
                const itemHeight = item.implicitHeight + spacing;

                if (y >= itemY && y <= itemY + itemHeight) {
                    popouts.currentName = area.name;
                    popouts.currentCenter = Qt.binding(() => statusIconsLoader.y + statusIconsInner.y + item.y + item.implicitHeight / 2);
                    popouts.hasCurrent = true;
                    statusIconFound = true;
                    break;
                }
            }
        }

        if (aw && y >= awy && y <= awy + aw.implicitHeight) {
            popouts.currentName = "activewindow";
            popouts.currentCenter = Qt.binding(() => activeWindowLoader.y + aw.y + aw.implicitHeight / 2);
            popouts.hasCurrent = true;

        } else if (clockLoader && y >= clockY && y <= clockY + clockHeight && Config.bar.clock.showCalendar) {
            const style = Config.bar.clock.style || "advanced";
            popouts.currentName = style === "simple" ? "calendar-simple" : "calendar-advanced";
            popouts.currentCenter = Qt.binding(() => clockLoader.y + clockLoader.implicitHeight / 2);
            popouts.hasCurrent = true;

        } else if (trayLoader && y > ty && y < ty + th && trayItems) {
            const index = Math.floor(((y - ty) / th) * trayItems.count);
            const item = trayItems.itemAt(index);

            popouts.currentName = `traymenu${index}`;
            popouts.currentCenter = Qt.binding(() => trayLoader.y + item.y + item.implicitHeight / 2);
            popouts.hasCurrent = true;

        } else if (!statusIconFound) {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        const ch = childAt(width / 2, y) as WrappedLoader;
        if (ch?.id === "workspaces") {
            const mon = (Config.bar.workspaces.perMonitorWorkspaces ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hyprland.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (Config.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hyprland.activeWsId) > 1)
                Hyprland.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (y < screen.height / 2) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + 0.1);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - 0.1);
        }
    }

    implicitWidth: {
        // Dynamically compute max width of all repeater items
        let maxWidth = 0;
        for (let i = 0; i < repeater.count; i++) {
            let item = repeater.itemAt(i);
            if (item && item.implicitWidth > maxWidth)
                maxWidth = item.implicitWidth;
        }
        return maxWidth + Config.border.thickness * 2;
    }

    spacing: Appearance.spacing.normal

    Repeater {
        id: repeater

        model: Config.bar.entries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    Layout.fillHeight: enabled
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    id: logo
                    sourceComponent: OsIcon {}
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    id: workspaces
                    sourceComponent: Workspaces {
                        screen: root.screen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    id: activeWindow
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    id: tray
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    id: clock
                    sourceComponent: Clock {}
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: WrappedLoader {
                    id: statusIcons
                    sourceComponent: StatusIcons {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    id: power
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
        }
    }

    component WrappedLoader: Loader {
        required property bool enabled
        required property string id
        required property int index

        function findFirstEnabled(): Item {
            const count = repeater.count;
            for (let i = 0; i < count; i++) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        function findLastEnabled(): Item {
            for (let i = repeater.count - 1; i >= 0; i--) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        Layout.alignment: Qt.AlignHCenter

        Layout.topMargin: findFirstEnabled() === this ? root.vPadding : 0
        Layout.bottomMargin: findLastEnabled() === this ? root.vPadding : 0

        visible: enabled
        active: enabled
    }
}