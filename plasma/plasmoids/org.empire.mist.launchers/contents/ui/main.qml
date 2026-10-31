/*
    Empire Launchers — pinned applications as compact monochrome icons.

    Why not the native Icons-only Task Manager: it always draws the original,
    full-color application icons and cannot restyle them. The design asks for
    a coherent monochrome row in the panel *without* touching the system icon
    theme (menus, Alt+Tab and Dolphin keep the real icons). So this applet
    reuses the exact same model as the task manager (libtaskmanager's
    TasksModel: launchers, running state, activation) and only changes how
    the icon is painted: desaturated and tinted with the color scheme's text
    color by a static MultiEffect layer (rendered once per icon change).

    Pin:   drag an app from the Arch menu onto the row, or right-click → Pin,
           or edit the list in Configure.
    Unpin: right-click → Unpin.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // Relative to the applet height Plasma gives us (30px bar → 22px): 1.0 = full height.
    readonly property int iconSize: Math.max(16, Math.round(root.height * Plasmoid.configuration.iconScale))
    property var menuTask: null

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.TasksModel {
        id: tasksModel

        launchInPlace: true
        separateLaunchers: false
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false

        // Keep the config as the single source of truth for pinned apps.
        onLauncherListChanged: {
            if (JSON.stringify(Plasmoid.configuration.launchers) !== JSON.stringify(launcherList)) {
                Plasmoid.configuration.launchers = launcherList;
            }
        }
        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
    }

    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() {
            if (JSON.stringify(Plasmoid.configuration.launchers) !== JSON.stringify(tasksModel.launcherList)) {
                tasksModel.launcherList = Plasmoid.configuration.launchers;
            }
        }
    }

    function activeChildRow(row: int, childCount: int): int {
        for (let c = 0; c < childCount; ++c) {
            if (tasksModel.data(tasksModel.makeModelIndex(row, c), TaskManager.AbstractTasksModel.IsActive)) {
                return c;
            }
        }
        return -1;
    }

    function activate(task): void {
        const idx = tasksModel.makeModelIndex(task.index);
        if (task.model.IsGroupParent) {
            // Several windows of one app: cycle through them.
            const active = activeChildRow(task.index, task.model.ChildCount);
            const next = active < 0 ? 0 : (active + 1) % task.model.ChildCount;
            tasksModel.requestActivate(tasksModel.makeModelIndex(task.index, next));
        } else if (task.model.IsWindow && task.model.IsActive) {
            tasksModel.requestToggleMinimized(idx);
        } else {
            // Launchers start the app; windows get focus.
            tasksModel.requestActivate(idx);
        }
    }

    PlasmaExtras.Menu {
        id: taskMenu

        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("New Window")
            icon: "window-new"
            visible: root.menuTask !== null && root.menuTask.model.CanLaunchNewInstance !== false
            onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(root.menuTask.index))
        }
        PlasmaExtras.MenuItem {
            text: i18n("Pin")
            icon: "window-pin"
            visible: root.menuTask !== null && !root.menuTask.pinned
            onClicked: tasksModel.requestAddLauncher(root.menuTask.model.LauncherUrlWithoutIcon)
        }
        PlasmaExtras.MenuItem {
            text: i18n("Unpin")
            icon: "window-unpin"
            visible: root.menuTask !== null && root.menuTask.pinned
            onClicked: tasksModel.requestRemoveLauncher(root.menuTask.model.LauncherUrlWithoutIcon)
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Close")
            icon: "window-close"
            visible: root.menuTask !== null && root.menuTask.model.IsWindow === true
            onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(root.menuTask.index))
        }
        PlasmaExtras.MenuItem {
            text: i18n("Configure Launchers…")
            icon: "configure"
            onClicked: Plasmoid.internalAction("configure").trigger()
        }
    }

    fullRepresentation: DropArea {
        id: dropArea

        Layout.minimumWidth: Math.max(row.implicitWidth, Kirigami.Units.iconSizes.small)
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        onDropped: drop => {
            for (const url of drop.urls) {
                if (url.toString().endsWith(".desktop")) {
                    tasksModel.requestAddLauncher(url);
                }
            }
        }

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: Plasmoid.configuration.spacing

            Repeater {
                model: tasksModel

                delegate: PlasmaCore.ToolTipArea {
                    id: task

                    required property int index
                    required property var model

                    readonly property bool pinned: model.IsLauncher === true || model.HasLauncher === true
                    readonly property bool running: model.IsWindow === true

                    visible: pinned || Plasmoid.configuration.showUnpinned
                    width: visible ? root.iconSize + 8 : 0
                    height: root.height
                    mainText: model.AppName || model.display || ""
                    subText: model.IsGroupParent ? i18np("%1 window", "%1 windows", model.ChildCount) : ""

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        visible: mouse.containsMouse || dropArea.containsDrag
                        color: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.highlightColor, 0.55))
                    }

                    Kirigami.Icon {
                        id: icon
                        anchors.centerIn: parent
                        width: root.iconSize
                        height: root.iconSize
                        source: task.model.decoration
                        active: mouse.containsMouse

                        layer.enabled: Plasmoid.configuration.monochrome
                        layer.effect: MultiEffect {
                            saturation: -1.0
                            colorization: Plasmoid.configuration.tintStrength
                            colorizationColor: Kirigami.Theme.textColor
                            brightness: task.model.IsActive ? 0.12 : 0.0
                        }
                    }

                    // Running marker: short line under the icon (in the panel's bottom
                    // margin), longer when focused.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 1
                        visible: task.running
                        width: task.model.IsActive ? Math.round(root.iconSize * 0.5) : 4
                        height: 2
                        radius: 1
                        color: task.model.IsDemandingAttention ? Kirigami.Theme.highlightColor
                             : task.model.IsActive ? Kirigami.Theme.textColor
                             : Kirigami.Theme.disabledTextColor
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouseEvent => {
                            if (mouseEvent.button === Qt.MiddleButton) {
                                tasksModel.requestNewInstance(tasksModel.makeModelIndex(task.index));
                            } else if (mouseEvent.button === Qt.RightButton) {
                                root.menuTask = task;
                                taskMenu.visualParent = task;
                                taskMenu.openRelative();
                            } else {
                                root.activate(task);
                            }
                        }
                    }
                }
            }
        }
    }
}
