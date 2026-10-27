/*
    Empire Power — one icon at the far right, one native menu:
    Lock · Sleep · Log Out · Restart · Shut Down

    Why not the native Lock/Logout widget: it puts one icon per action in the
    panel. The design asks for a single icon with a menu. The actions call
    Plasma's own SessionManagement (the backend of Lock/Logout and Kickoff),
    so the usual confirmation screen and its countdown still apply.
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions as Sessions

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: i18n("Power")

    Sessions.SessionManagement {
        id: session
    }

    PlasmaExtras.Menu {
        id: menu

        placement: PlasmaExtras.Menu.BottomPosedRightAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("Lock")
            icon: "system-lock-screen"
            visible: session.canLock
            onClicked: session.lock()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Sleep")
            icon: "system-suspend"
            visible: session.canSuspend
            onClicked: session.suspend()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Log Out…")
            icon: "system-log-out"
            visible: session.canLogout
            onClicked: session.requestLogout()
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Restart…")
            icon: "system-reboot"
            visible: session.canReboot
            onClicked: session.requestReboot()
        }
        PlasmaExtras.MenuItem {
            text: i18n("Shut Down…")
            icon: "system-shutdown"
            visible: session.canShutdown
            onClicked: session.requestShutdown()
        }
    }

    fullRepresentation: MouseArea {
        id: button

        readonly property int iconSize: Math.max(14, Math.round(root.height * 0.6))

        Layout.minimumWidth: iconSize + 14
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            menu.visualParent = button;
            menu.openRelative();
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Math.round(parent.height * 0.72)
            radius: 5
            visible: button.containsMouse || menu.status === PlasmaExtras.Menu.Open
            color: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.highlightColor, 0.55))
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            source: "system-shutdown-symbolic"
            color: Kirigami.Theme.textColor
            isMask: true
        }
    }
}
