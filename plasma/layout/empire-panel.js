// Empire Mist — vertical bar on the left, built with the Plasma 6 Desktop
// Scripting API. install.sh fills the @PLACEHOLDERS@ and runs this through
// org.kde.PlasmaShell.evaluateScript. Only panels are touched: desktop
// containments (and therefore the wallpaper) are left alone.
//
// Top → bottom:
//   Arch menu · I II III · apps · (space) · tray · keyboard · network · volume
//   · battery · clock · notifications · power

const THICKNESS = @THICKNESS@;
const KICKOFF_ICON = @KICKOFF_ICON@;
const LAUNCHERS = @LAUNCHERS@;
const WITH_BATTERY = @WITH_BATTERY@;
const REPLACE_PANELS = @REPLACE_PANELS@;

// Indicators that get their own slot in the bar, so the tray must not show them again.
const STANDALONE = [
    "org.kde.plasma.keyboardlayout",
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications",
].concat(WITH_BATTERY ? ["org.kde.plasma.battery"] : []);
// Tray plasmoids allowed to appear (most of them only when relevant).
const TRAY_EXTRA = [
    "org.kde.plasma.bluetooth",
    "org.kde.plasma.devicenotifier",   // only while a USB drive is plugged in
    "org.kde.plasma.cameraindicator",  // only while the camera is in use (handy when streaming)
    "org.kde.kdeconnect",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.mediacontroller",
].concat(WITH_BATTERY ? [] : ["org.kde.plasma.battery"]);
// Always folded into the tray's overflow arrow.
const TRAY_HIDDEN = [
    "org.kde.plasma.clipboard",
    "org.kde.plasma.mediacontroller",  // no music module in the bar; media keys keep working
].concat(WITH_BATTERY ? [] : ["org.kde.plasma.battery"]);
// Marked as "known" so the tray does not auto-enable them; anything newer
// that Plasma ships later is still auto-enabled the normal way.
const TRAY_KNOWN = [
    "org.kde.plasma.keyboardlayout",
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.volume",
    "org.kde.plasma.notifications",
    "org.kde.plasma.battery",
    "org.kde.plasma.bluetooth",
    "org.kde.plasma.devicenotifier",
    "org.kde.plasma.cameraindicator",
    "org.kde.kdeconnect",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.mediacontroller",
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
];

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
panel.location = "left";
panel.height = THICKNESS;   // for a vertical panel "height" is its thickness (width)
panel.hiding = "none";
panel.alignment = "center";
panel.floating = false;
panel.lengthMode = "fill";
try { panel.opacity = "opaque"; } catch (e) {}   // Plasma >= 6.1; install.sh also writes it to plasmashellrc
try { panel.floatingApplets = false; } catch (e) {}

// ── top ─────────────────────────────────────────────────────────────────
add(panel, "org.kde.plasma.kickoff", { icon: KICKOFF_ICON });
add(panel, "org.empire.mist.ages");
// Native task manager: original app icons, running/active indicators, badges.
add(panel, "org.kde.plasma.icontasks", { launchers: LAUNCHERS });

// ── flexible space pushes the rest to the bottom ─────────────────────────
add(panel, "org.kde.plasma.panelspacer", { expanding: true });

// ── bottom ──────────────────────────────────────────────────────────────
const tray = add(panel, "org.kde.plasma.systemtray");
add(panel, "org.kde.plasma.keyboardlayout");
add(panel, "org.kde.plasma.networkmanagement");
add(panel, "org.kde.plasma.volume");
if (WITH_BATTERY) {
    add(panel, "org.kde.plasma.battery");
}
add(panel, "org.empire.mist.clock");
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
print("EMPIRE_TRAY_EXTRA=" + TRAY_EXTRA.join(","));
print("EMPIRE_TRAY_HIDDEN=" + TRAY_HIDDEN.join(","));
print("EMPIRE_TRAY_KNOWN=" + TRAY_KNOWN.join(","));
