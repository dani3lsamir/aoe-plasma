/*
    Empire Ages — virtual desktop indicator: I  II  III

    Why not the native Pager: the pager draws miniature desktops (frames with
    window outlines). The design asks for bare roman numerals where the active
    desktop gets a slate capsule plus a short mist underline. The pager has no
    such mode, so this is a tiny event-driven replacement:
      - desktop list / current desktop: libtaskmanager's VirtualDesktopInfo
        (signals from KWin, no polling)
      - switching: one async D-Bus call to org.kde.KWin.setCurrentDesktop
    The thematic names (Dark Age, Feudal Age, Castle Age) live in KWin's own
    desktop names and only show up in the tooltip, Overview and the OSD.
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    readonly property int currentIndex: desktopInfo.desktopIds.indexOf(desktopInfo.currentDesktop)
    readonly property int count: desktopInfo.numberOfDesktops

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // In a vertical bar, take the full bar width like the native task manager
    // does (no panel margins), so everything lines up with the app icons.
    Plasmoid.constraintHints: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? Plasmoid.CanFillArea : 0

    TaskManager.VirtualDesktopInfo {
        id: desktopInfo
    }

    function roman(n: int): string {
        const table = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let out = "";
        for (const [value, glyph] of table) {
            while (n >= value) {
                out += glyph;
                n -= value;
            }
        }
        return out;
    }

    function activate(index: int): void {
        if (index < 0 || index >= count || index === currentIndex) {
            return;
        }
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin",
            path: "/KWin",
            iface: "org.kde.KWin",
            member: "setCurrentDesktop",
            arguments: [index + 1],
            signature: "(i)"
        });
    }

    function step(delta: int): void {
        let next = currentIndex + delta;
        if (desktopInfo.navigationWrappingAround) {
            next = (next + count) % count;
        }
        activate(next);
    }

    fullRepresentation: MouseArea {
        id: area

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        // Vertical: the full bar width (32px bar → 32px). Horizontal: the panel
        // thickness minus the Breeze panel margins (30px bar → 22px tall).
        readonly property int thickness: Math.max(16, Math.round(vertical ? root.width : root.height))
        readonly property int capsuleLength: vertical ? Math.round(thickness * 0.66) : thickness
        readonly property int numeralSize: Math.round((vertical ? thickness * 0.34 : thickness * 0.55))
        property int wheelDelta: 0

        Layout.minimumWidth: vertical ? 0 : grid.implicitWidth
        Layout.preferredWidth: vertical ? -1 : grid.implicitWidth
        Layout.maximumWidth: vertical ? Infinity : grid.implicitWidth
        Layout.minimumHeight: vertical ? grid.implicitHeight : 0
        Layout.preferredHeight: vertical ? grid.implicitHeight : -1
        Layout.maximumHeight: vertical ? grid.implicitHeight : Infinity
        Layout.fillWidth: vertical
        Layout.fillHeight: !vertical

        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            wheelDelta += wheel.angleDelta.y || wheel.angleDelta.x;
            while (Math.abs(wheelDelta) >= 120) {
                root.step(wheelDelta > 0 ? -1 : 1);
                wheelDelta += wheelDelta > 0 ? -120 : 120;
            }
        }

        // I II III side by side in a horizontal bar, stacked in a vertical one.
        Grid {
            id: grid
            anchors.centerIn: parent
            columns: area.vertical ? 1 : root.count
            spacing: Plasmoid.configuration.spacing

            Repeater {
                model: root.count

                delegate: PlasmaCore.ToolTipArea {
                    id: age

                    required property int index
                    readonly property bool isCurrent: index === root.currentIndex

                    width: area.vertical ? area.thickness : Math.max(area.thickness + 6, label.implicitWidth + 16)
                    height: area.capsuleLength
                    mainText: desktopInfo.desktopNames[index] ?? ""
                    // Tooltip only when KWin has a real name (e.g. "Feudal Age") for this desktop.
                    active: mainText.length > 0 && mainText !== label.text

                    Rectangle {
                        anchors.fill: parent
                        radius: Plasmoid.configuration.capsuleRadius
                        visible: age.isCurrent || hover.containsMouse
                        // Solid colors only: highlight (slate) for the active desktop,
                        // a slate tint over the panel background on hover.
                        color: age.isCurrent ? Kirigami.Theme.highlightColor
                                          : Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.highlightColor, 0.55))
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: root.roman(age.index + 1)
                        color: age.isCurrent ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                        font.family: Plasmoid.configuration.fontFamily || Kirigami.Theme.defaultFont.family
                        font.pixelSize: area.numeralSize
                        font.weight: age.isCurrent ? Font.DemiBold : Font.Normal
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 10
                        height: 2
                        radius: 1
                        visible: age.isCurrent
                        color: Kirigami.Theme.textColor
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(age.index)
                    }
                }
            }
        }
    }
}
