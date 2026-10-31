/*
    Empire Clock — "Oct 26 · 4:27 P", centered on the screen, click for the calendar.

    Why not the native Digital Clock:
      1. Centering. A panel lays widgets out in a row, so a clock between two
         flexible spacers is centered between the left and right groups, not
         on the screen: whenever the groups differ in width (music appears,
         a tray icon shows up), the clock drifts. Here the applet fills the
         whole middle of the panel and places the text at the panel window's
         center, so side modules never move it.
      2. Format. The Digital Clock follows the locale's time format and cannot
         produce a one-letter A/P suffix.
    The calendar is KDE's own MonthView (the one inside the Digital Clock
    popup), opened in a Plasma dialog anchored under the text.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property var now: timeSource.item ? timeSource.item.dateTime : new Date()
    readonly property var locale: Qt.locale(Plasmoid.configuration.localeName || Qt.locale().name)
    readonly property string text: formatClock(now)

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // Same mechanism as Plasma's own flexible spacer: take all free panel width.
    Layout.fillWidth: true
    Layout.fillHeight: true

    toolTipMainText: now.toLocaleDateString(locale, Locale.LongFormat)

    // Plasma >= 6.6 ships org.kde.plasma.clock; older releases use the time
    // data engine. Try the modern one, fall back if the module is missing.
    Loader {
        id: timeSource
        source: "ClockSourceModern.qml"
        onStatusChanged: {
            if (status === Loader.Error && source.toString().indexOf("Modern") !== -1) {
                source = "ClockSourceLegacy.qml";
            }
        }
    }

    function pad(n: int): string {
        return n < 10 ? "0" + n : String(n);
    }

    function formatClock(d): string {
        const minutes = pad(d.getMinutes());
        let time;
        if (Plasmoid.configuration.twentyFourHour) {
            time = pad(d.getHours()) + ":" + minutes;
        } else {
            const h = d.getHours() % 12 || 12;
            time = h + ":" + minutes + " " + (d.getHours() < 12 ? "A" : "P");
        }
        if (!Plasmoid.configuration.showDate) {
            return time;
        }
        const month = root.locale.monthName(d.getMonth(), Locale.ShortFormat).replace(".", "");
        return month + " " + d.getDate() + " · " + time;
    }

    fullRepresentation: Item {
        id: band

        property real textX: 0
        property var watched: []

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: clockArea.width
        Layout.preferredWidth: clockArea.width

        // Put the text at the panel window's horizontal center (the panel
        // spans the whole screen, so that is the screen center), clamped
        // so it never overlaps the neighbouring widgets.
        function recenter(): void {
            const win = band.Window.window;
            if (!win || band.width <= 0) {
                return;
            }
            const origin = band.mapToItem(null, 0, 0);
            const wanted = win.width / 2 - origin.x - clockArea.width / 2;
            band.textX = Math.round(Math.max(0, Math.min(band.width - clockArea.width, wanted)));
        }

        function queueRecenter(): void {
            Qt.callLater(band.recenter);
        }

        // Our x inside the panel changes whenever a widget on the left grows
        // or shrinks; those changes arrive as x/width changes on our
        // ancestors, so listen to them (no timers, no polling).
        function watchAncestors(): void {
            unwatchAncestors();
            for (let p = band.parent; p; p = p.parent) {
                p.xChanged.connect(band.queueRecenter);
                p.widthChanged.connect(band.queueRecenter);
                band.watched.push(p);
            }
        }

        function unwatchAncestors(): void {
            for (const p of band.watched) {
                p.xChanged.disconnect(band.queueRecenter);
                p.widthChanged.disconnect(band.queueRecenter);
            }
            band.watched = [];
        }

        onWidthChanged: queueRecenter()
        onXChanged: queueRecenter()
        onParentChanged: {
            watchAncestors();
            queueRecenter();
        }
        Component.onCompleted: {
            watchAncestors();
            queueRecenter();
        }
        Component.onDestruction: unwatchAncestors()

        Connections {
            target: band.Window.window
            function onWidthChanged() {
                band.queueRecenter();
            }
        }

        MouseArea {
            id: clockArea

            x: band.textX
            width: label.implicitWidth + 16
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onWidthChanged: band.queueRecenter()
            onClicked: calendar.toggle()

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: 5
                visible: clockArea.containsMouse || calendar.shown
                color: calendar.shown ? Kirigami.Theme.highlightColor
                                      : Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.highlightColor, 0.55))
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: root.text
                color: Kirigami.Theme.textColor
                font.family: Plasmoid.configuration.fontFamily || Kirigami.Theme.defaultFont.family
                font.pixelSize: Math.round(root.height * Plasmoid.configuration.fontScale)
                font.letterSpacing: Plasmoid.configuration.letterSpacing
                renderType: Text.NativeRendering
            }
        }

        CalendarPopup {
            id: calendar
            anchorItem: clockArea
            today: root.now
        }
    }
}
