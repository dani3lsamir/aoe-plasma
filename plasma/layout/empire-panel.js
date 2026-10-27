// Empire Mist — top bar, built with the Plasma 6 Desktop Scripting API.
// install.sh fills the @PLACEHOLDERS@ and runs this through
// org.kde.PlasmaShell.evaluateScript. Only panels are touched: desktop
// containments (and therefore the wallpaper) are left alone.
//
// Layout (left → right):
//   Arch menu │ I II III │ pinned apps │ media      CLOCK      tray │ ES BT Wi-Fi Vol Notif Power

const THICKNESS = @THICKNESS@;
const KICKOFF_ICON = @KICKOFF_ICON@;
const LAUNCHERS = @LAUNCHERS@;
const WITH_BLUETOOTH = @WITH_BLUETOOTH@;
const REPLACE_PANELS = @REPLACE_PANELS@;

// Indicators that get their own slot in the bar, so the tray must not show them again.
const STANDALONE = [
    "org.kde.plasma.keyboardlayout",
    "org.kde.plasma.bluetooth",
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications",
];
// Tray plasmoids allowed to appear (most of them only when relevant).
const TRAY_EXTRA = [
    "org.kde.plasma.devicenotifier",   // only while a USB drive is plugged in
    "org.kde.plasma.cameraindicator",  // only while the camera is in use (handy when streaming)
    "org.kde.kdeconnect",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.mediacontroller",
    "org.kde.plasma.battery",
];
// Always folded into the tray's overflow arrow.
const TRAY_HIDDEN = [
    "org.kde.plasma.clipboard",
    "org.kde.plasma.mediacontroller",  // Empire Media replaces it in the bar
    "org.kde.plasma.battery",
];
// Marked as "known" so the tray does not auto-enable them; anything newer
// that Plasma ships later is still auto-enabled the normal way.
const TRAY_KNOWN = STANDALONE.concat(TRAY_EXTRA, [
    "org.kde.plasma.keyboardindicator",
    "org.kde.plasma.manage-inputmethod",
    "org.kde.plasma.printmanager",
    "org.kde.plasma.vault",
    "org.kde.plasma.weather",
    "org.kde.plasma.brightness",
    "org.kde.plasma.nightcolorcontrol",
    "org.kde.plasma.nightlight",
    "org.kde.kscreen",
    "org.kde.plasma.colorpicker",
    "org.kde.plasma.systemmonitor",
]);

function configure(widget, group, values) {
    widget.currentConfigGroup = group;
    for (const key in values) {
        widget.writeConfig(key, values[key]);
    }
    widget.currentConfigGroup = [];
}

function add(panel, plugin, config) {
    if (knownWidgetTypes.indexOf(plugin) === -1) {
        print("EMPIRE_SKIP=" + plugin);
        return null;
    }
    const widget = panel.addWidget(plugin);
    if (config) {
        configure(widget, ["General"], config);
    }
    return widget;
}

if (REPLACE_PANELS) {
    for (const old of panels()) {
        old.remove();
    }
}

const panel = new Panel();
panel.location = "top";
panel.height = THICKNESS;
panel.hiding = "none";
panel.alignment = "center";
panel.floating = false;
panel.lengthMode = "fill";
panel.opacity = "opaque";   // Plasma >= 6.1; install.sh also writes it to plasmashellrc
try { panel.floatingApplets = false; } catch (e) {}

// ── left ────────────────────────────────────────────────────────────────
add(panel, "org.kde.plasma.kickoff", { icon: KICKOFF_ICON });
add(panel, "org.empire.mist.ages");
add(panel, "org.empire.mist.separator");
add(panel, "org.empire.mist.launchers", { launchers: LAUNCHERS });
add(panel, "org.empire.mist.media");

// ── center (fills the middle, keeps its text at the screen center) ────────
add(panel, "org.empire.mist.clock");

// ── right ───────────────────────────────────────────────────────────────
const tray = add(panel, "org.kde.plasma.systemtray");
add(panel, "org.empire.mist.separator");
add(panel, "org.kde.plasma.keyboardlayout");
if (WITH_BLUETOOTH) {
    add(panel, "org.kde.plasma.bluetooth");
}
add(panel, "org.kde.plasma.networkmanagement");
add(panel, "org.kde.plasma.volume");
add(panel, "org.kde.plasma.notifications");
add(panel, "org.empire.mist.power");

// System tray: Plasma <= 6.3 keeps its items in a separate inner containment
// (SystrayContainmentId); newer releases keep them on the tray applet itself.
const trayConfig = {
    extraItems: TRAY_EXTRA,
    hiddenItems: TRAY_HIDDEN,
    knownItems: TRAY_KNOWN,
    shownItems: [],
    scaleIconsToFit: false,
};
let trayContainmentId = 0;
if (tray) {
    configure(tray, ["General"], trayConfig);
    tray.currentConfigGroup = [];
    trayContainmentId = Number(tray.readConfig("SystrayContainmentId", 0)) || 0;
    if (trayContainmentId > 0) {
        const inner = desktopById(trayContainmentId);
        if (inner) {
            configure(inner, ["General"], trayConfig);
        }
    }
}

print("EMPIRE_PANEL=" + panel.id);
print("EMPIRE_TRAY=" + (tray ? tray.id : 0));
print("EMPIRE_TRAY_CONTAINMENT=" + trayContainmentId);
print("EMPIRE_SCREEN=" + panel.screen);
