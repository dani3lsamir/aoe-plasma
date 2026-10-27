// Plasma >= 6.6: the shared clock object Plasma's own Digital Clock uses.
// Ticks once per minute and follows time zone / system clock changes.
import QtQuick
import org.kde.plasma.clock

Item {
    readonly property var dateTime: clock.dateTime

    Clock {
        id: clock
    }
}
