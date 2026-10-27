import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property var cfg_launchers: []
    property alias cfg_monochrome: monochrome.checked
    property alias cfg_tintStrength: tint.value
    property alias cfg_showUnpinned: showUnpinned.checked
    property alias cfg_iconScale: scale.value

    Kirigami.FormLayout {
        QQC2.TextArea {
            id: list
            Kirigami.FormData.label: i18n("Pinned apps:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            Layout.preferredHeight: Kirigami.Units.gridUnit * 8
            font.family: "monospace"
            placeholderText: "applications:org.kde.dolphin.desktop"
            text: page.cfg_launchers.join("\n")
            onTextChanged: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l.length > 0)
                    .map(l => (l.includes(":") || l.startsWith("/")) ? l : "applications:" + (l.endsWith(".desktop") ? l : l + ".desktop"));
                if (JSON.stringify(lines) !== JSON.stringify(page.cfg_launchers)) {
                    page.cfg_launchers = lines;
                }
            }
        }
        QQC2.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.8
            text: i18n("One desktop file per line (\"org.kde.konsole\" is enough). You can also drag apps from the application menu onto the panel row.")
        }
        QQC2.CheckBox {
            id: monochrome
            Kirigami.FormData.label: i18n("Icons:")
            text: i18n("Monochrome (panel only)")
        }
        QQC2.Slider {
            id: tint
            Kirigami.FormData.label: i18n("Tint strength:")
            enabled: monochrome.checked
            from: 0.0
            to: 1.0
            stepSize: 0.05
        }
        QQC2.Slider {
            id: scale
            Kirigami.FormData.label: i18n("Icon size:")
            from: 0.5
            to: 0.9
            stepSize: 0.02
        }
        QQC2.CheckBox {
            id: showUnpinned
            Kirigami.FormData.label: i18n("Running apps:")
            text: i18n("Also show apps that are not pinned")
        }
    }
}
