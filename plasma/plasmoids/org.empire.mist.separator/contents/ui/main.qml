/*
    Empire Separator — a 1px line. Plasma's own spacer only adds empty space,
    the design asks for a visible but quiet divider (see the mockup).
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    fullRepresentation: Item {
        readonly property int lineWidth: 1

        Layout.minimumWidth: lineWidth + 2 * Plasmoid.configuration.margin
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: parent.lineWidth
            height: Math.round(parent.height * 0.5)
            // Solid mix of panel background and text color: visible, never loud.
            color: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.textColor, 0.22))
        }
    }
}
