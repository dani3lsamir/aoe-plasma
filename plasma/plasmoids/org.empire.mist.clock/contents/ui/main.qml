/*
    Empire Clock — time over date at the bottom of the vertical bar:

        1:38
        10/31

    Click for the KDE calendar.

    Why not the native Digital Clock: in 12-hour mode it always appends the
    locale's AM/PM suffix ("1:38 PM"), which does not fit a narrow vertical
    bar and is not the requested look. The calendar is KDE's own MonthView
    (the one inside the Digital Clock popup), opened in a Plasma dialog next
    to the clock. In a horizontal panel it falls back to one line.
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var now: timeSource.item ? timeSource.item.dateTime : new Date()
    readonly property var locale: Qt.locale(Plasmoid.configuration.localeName || Qt.locale().name)
    readonly property string timeText: formatTime(now)
    readonly property string dateText: Plasmoid.configuration.showDate
        ? now.toLocaleDateString(locale, Plasmoid.configuration.dateFormat) : ""

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // In a vertical bar, take the full bar width like the native task manager
    // does (no panel margins), so everything lines up with the app icons.
    Plasmoid.constraintHints: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? Plasmoid.CanFillArea : 0

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

    function formatTime(d): string {
        const minutes = pad(d.getMinutes());
        if (Plasmoid.configuration.twentyFourHour) {
            return pad(d.getHours()) + ":" + minutes;
        }
        const time = (d.getHours() % 12 || 12) + ":" + minutes;
        return Plasmoid.configuration.showAmPm ? time + " " + (d.getHours() < 12 ? "A" : "P") : time;
    }

    fullRepresentation: MouseArea {
        id: area

        // Vertical: full bar width (32px bar → 32px). Horizontal: panel thickness
        // minus the Breeze panel margins (30px bar → 22px tall).
        readonly property int thickness: Math.max(16, Math.round(root.vertical ? root.width : root.height))
        readonly property int wantedSize: Math.round(thickness * (root.vertical ? Plasmoid.configuration.fontScale : 0.6))
        // In a narrow vertical bar, shrink the text if the longer line would not fit.
        // (3% safety margin: glyph widths do not scale perfectly with the size.)
        readonly property int textSize: root.vertical && widest.width > thickness - 4
            ? Math.max(8, Math.floor(wantedSize * (thickness - 4) / widest.width * 0.97))
            : wantedSize

        TextMetrics {
            id: widest
            font.family: Plasmoid.configuration.fontFamily || Kirigami.Theme.defaultFont.family
            font.pixelSize: area.wantedSize
            text: root.timeText.length > root.dateText.length ? root.timeText : root.dateText
        }

        Layout.minimumWidth: root.vertical ? 0 : content.implicitWidth + 16
        Layout.preferredWidth: root.vertical ? -1 : content.implicitWidth + 16
        Layout.maximumWidth: root.vertical ? Infinity : content.implicitWidth + 16
        Layout.minimumHeight: root.vertical ? content.implicitHeight + 10 : 0
        Layout.preferredHeight: root.vertical ? content.implicitHeight + 10 : -1
        Layout.maximumHeight: root.vertical ? content.implicitHeight + 10 : Infinity
        Layout.fillWidth: root.vertical
        Layout.fillHeight: !root.vertical

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: calendar.toggle()

        Rectangle {
            anchors.fill: parent
            radius: 5
            visible: area.containsMouse || calendar.shown
            color: calendar.shown ? Kirigami.Theme.highlightColor
                                  : Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.highlightColor, 0.55))
        }

        // Vertical: time over date. Horizontal: "10/31 · 1:38" on one line.
        Grid {
            id: content
            anchors.centerIn: parent
            columns: root.vertical ? 1 : 3
            columnSpacing: 6
            horizontalItemAlignment: Grid.AlignHCenter

            Text {
                visible: !root.vertical && root.dateText.length > 0
                text: root.dateText
                color: Kirigami.Theme.textColor
                font.family: Plasmoid.configuration.fontFamily || Kirigami.Theme.defaultFont.family
                font.pixelSize: area.textSize
                renderType: Text.NativeRendering
            }
            Text {
                visible: !root.vertical && root.dateText.length > 0
                text: "·"
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: area.textSize
                renderType: Text.NativeRendering
            }
            Text {
                text: root.timeText
                color: Kirigami.Theme.textColor
                font.family: Plasmoid.configuration.fontFamily || Kirigami.Theme.defaultFont.family
                font.pixelSize: area.textSize
                renderType: Text.NativeRendering
            }
            Text {
                visible: root.vertical && root.dateText.length > 0
                text: root.dateText
                color: Kirigami.Theme.textColor
                font.family: Plasmoid.configuration.fontFamily || Kirigami.Theme.defaultFont.family
                font.pixelSize: area.textSize
                renderType: Text.NativeRendering
            }
        }

        CalendarPopup {
            id: calendar
            anchorItem: area
            today: root.now
        }
    }
}
