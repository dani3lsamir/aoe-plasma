/*
    The KDE calendar (PlasmaCalendar.MonthView, the same component as in the
    Digital Clock popup) in a solid Plasma dialog placed next to the clock
    (to the right of a left vertical bar). Created on first use only.
*/
import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

Item {
    id: popup

    property Item anchorItem
    property var today: new Date()
    readonly property bool shown: loader.item ? loader.item.visible : false
    property real hiddenAt: 0

    function toggle(): void {
        if (!loader.active) {
            loader.active = true;
        }
        const dialog = loader.item;
        if (dialog.visible) {
            dialog.visible = false;
        } else if (Date.now() - hiddenAt < 300) {
            // Clicking the clock while the calendar is open first takes focus
            // away from it (hideOnWindowDeactivate closes it), then delivers
            // the click: that click meant "close", so do not reopen.
            return;
        } else {
            dialog.visible = true;
            dialog.requestActivate();
        }
    }

    Loader {
        id: loader
        active: false

        sourceComponent: PlasmaCore.Dialog {
            id: dialog

            visualParent: popup.anchorItem
            location: Plasmoid.location
            type: PlasmaCore.Dialog.PopupMenu
            flags: Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.SolidBackground
            hideOnWindowDeactivate: true

            mainItem: FocusScope {
                width: Kirigami.Units.gridUnit * 20
                height: Kirigami.Units.gridUnit * 19
                focus: true

                Keys.onEscapePressed: dialog.visible = false

                PlasmaCalendar.MonthView {
                    id: monthView
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    borderOpacity: 0.25
                    today: popup.today
                    firstDayOfWeek: Qt.locale().firstDayOfWeek
                    showWeekNumbers: false
                }
            }

            onVisibleChanged: {
                if (visible) {
                    // Always open on the current month.
                    monthView.resetToToday();
                } else {
                    popup.hiddenAt = Date.now();
                }
            }
        }
    }
}
