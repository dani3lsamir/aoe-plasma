#!/usr/bin/env bash
# Empire Plasma — Mist Edition installer for CachyOS / Arch + KDE Plasma 6.
#
#   ./install.sh             detect → preview → ask → back up → apply → verify
#   ./install.sh --dry-run   detect and preview only, change nothing
#   ./install.sh --help
#
# Everything it changes is backed up first; ./restore.sh puts it back.
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

DRY_RUN=0
DO_PANEL=1
REPLACE_PANELS=1
DO_SHELL=1
DO_KEYBOARD=1
DO_DESKTOPS=1
THICKNESS=30
KB_LAYOUTS="${EMPIRE_KB_LAYOUTS:-us,es}"
AGE_NAMES=("Dark Age" "Feudal Age" "Castle Age")

usage() {
    cat <<EOF
Empire Plasma — Mist Edition installer

Usage: ./install.sh [options]

  --dry-run          Detect the system and show what would change; touch nothing.
  -y, --yes          Answer "yes" to every question (still makes a backup).
  --keep-panels      Add the Empire bar but do not remove existing panels.
  --no-panel         Do not create the bar (colors, KWin, Konsole, prompt only).
  --no-shell         Do not add the prompt to any shell.
  --no-keyboard      Do not touch keyboard layouts.
  --no-desktops      Do not change the number/names of virtual desktops.
  --layouts LIST     Keyboard layouts when none are configured (default: $KB_LAYOUTS).
  --thickness PX     Bar thickness in pixels, 26–36 (default: $THICKNESS).
  -h, --help         This help.
EOF
}

while (( $# )); do
    case $1 in
        --dry-run) DRY_RUN=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        --keep-panels) REPLACE_PANELS=0 ;;
        --no-panel) DO_PANEL=0 ;;
        --no-shell) DO_SHELL=0 ;;
        --no-keyboard) DO_KEYBOARD=0 ;;
        --no-desktops) DO_DESKTOPS=0 ;;
        --layouts) KB_LAYOUTS=${2:?--layouts needs a value}; shift ;;
        --thickness) THICKNESS=${2:?--thickness needs a value}; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "Unknown option: $1" ;;
    esac
    shift
done
if ! [[ $THICKNESS =~ ^[0-9]+$ ]] || (( THICKNESS < 26 || THICKNESS > 36 )); then
    die "--thickness must be 26–36"
fi
[[ $KB_LAYOUTS =~ ^[a-z]+(,[a-z]+)*$ ]] || die "--layouts must look like us,es"

# ════════════════════════════════════════════════════════════════════════
# 1. Detection (read-only)
# ════════════════════════════════════════════════════════════════════════
step "Detecting the system"

(( EUID != 0 )) || die "Run as your normal user, not root: everything lives in your home directory."

OS_NAME="unknown"; OS_ID="unknown"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    OS_NAME=$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-$NAME}")
    OS_ID=$(. /etc/os-release; printf '%s' "${ID:-unknown}")
fi
info "OS: $OS_NAME"
[[ $OS_ID == cachyos ]] || warn "Not CachyOS ($OS_ID). Any Arch-based Plasma 6 system should work, but this was designed for CachyOS."

for cmd in plasmashell kwriteconfig6 kreadconfig6 busctl kquitapp6 plasma-apply-colorscheme plasma-apply-desktoptheme; do
    have "$cmd" || die "Missing '$cmd'. Install KDE Plasma 6 (plasma-meta) first."
done

PLASMA_VERSION=$(plasmashell --version 2>/dev/null | awk '{print $2}')
PLASMA_MAJOR=${PLASMA_VERSION%%.*}
PLASMA_MINOR=$(cut -d. -f2 <<< "$PLASMA_VERSION")
info "Plasma: $PLASMA_VERSION"
[[ $PLASMA_MAJOR == 6 ]] || die "KDE Plasma 6 is required (found '$PLASMA_VERSION')."
(( PLASMA_MINOR >= 2 )) || warn "Plasma 6.$PLASMA_MINOR is older than 6.2; the desktop indicator needs 6.2+ to switch desktops."

[[ ${XDG_CURRENT_DESKTOP:-} == *KDE* ]] || die "Run this from inside your Plasma session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})."
SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}
info "Session: $SESSION_TYPE"
plasmashell_running || die "plasmashell is not running on this session's D-Bus."

SCREENS="unknown"
if have kscreen-doctor; then
    SCREENS=$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
        | awk '/^Output:/{name=$3} /Geometry:/{print name" "$3; name=""}' | paste -sd',' - || true)
    SCREEN_COUNT=$(awk -F',' '{print NF}' <<< "$SCREENS")
    info "Monitors (${SCREEN_COUNT:-?}): ${SCREENS:-unknown}"
    [[ ${SCREEN_COUNT:-1} -le 1 ]] || info "The bar goes on the primary screen; other screens keep no panel."
else
    info "Monitors: kscreen-doctor not found, skipping"
fi

APPLETSRC="$CONFIG_HOME/plasma-org.kde.plasma.desktop-appletsrc"
PANEL_COUNT=0
[[ -f $APPLETSRC ]] && PANEL_COUNT=$(grep -c '^plugin=org.kde.panel$' "$APPLETSRC" || true)
info "Existing panels: $PANEL_COUNT"

DESKTOP_COUNT=$(kwin_desktop_count 2>/dev/null || echo "?")
info "Virtual desktops: $DESKTOP_COUNT"

CUR_SCHEME=$(kread kdeglobals General ColorScheme)
CUR_THEME=$(kread plasmarc Theme name)
info "Color scheme: ${CUR_SCHEME/$UNSET/(default)} · Plasma style: ${CUR_THEME/$UNSET/(default)}"

# Brave Origin: look for its .desktop file by display name (native or Flatpak).
BRAVE_ID=""
for dir in "$DATA_HOME/applications" /usr/share/applications /usr/local/share/applications \
           "$DATA_HOME/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications; do
    [[ -d $dir ]] || continue
    while IFS= read -r file; do
        if ! grep -qi '^NoDisplay=true' "$file"; then BRAVE_ID=$(basename "$file"); break 2; fi
    done < <(grep -lis '^Name=Brave Origin' "$dir"/*.desktop 2>/dev/null || true)
done
if [[ -n $BRAVE_ID ]]; then
    info "Brave Origin: found ($BRAVE_ID) — it will be pinned"
else
    info "Brave Origin: not installed — the pinned-apps row starts empty"
fi

HAS_BLUETOOTH=0
compgen -G "/sys/class/bluetooth/hci*" >/dev/null && HAS_BLUETOOTH=1
info "Bluetooth adapter: $([[ $HAS_BLUETOOTH == 1 ]] && echo yes || echo 'none (indicator skipped)')"

MONO_FONT="monospace"
for f in "JetBrains Mono" "Hack" "Fira Code" "Noto Sans Mono" "DejaVu Sans Mono"; do
    if fc-list -q "$f" 2>/dev/null; then MONO_FONT=$f; break; fi
done
info "Terminal font: $MONO_FONT"

KB_CURRENT=$(kread kxkbrc Layout LayoutList)
[[ $KB_CURRENT == "$UNSET" ]] && KB_CURRENT=""
info "Keyboard layouts: ${KB_CURRENT:-none configured (system default)}"

LOGIN_SHELL=$(basename "${SHELL:-bash}")
info "Login shell: $LOGIN_SHELL"

if [[ -L $EMPIRE_ORIGINAL ]]; then
    info "Empire Plasma is already installed; the original backup is kept as the restore point."
fi

# ════════════════════════════════════════════════════════════════════════
# 2. Preview
# ════════════════════════════════════════════════════════════════════════
LAUNCHERS_JSON="[]"
[[ -n $BRAVE_ID ]] && LAUNCHERS_JSON="[\"applications:$BRAVE_ID\"]"

if [[ -n $KB_CURRENT ]]; then
    KB_TARGET=$KB_CURRENT
else
    KB_TARGET=$KB_LAYOUTS
fi
KB_LABEL=${KB_TARGET^^}
KB_LABEL=${KB_LABEL//,/\/}

step "Planned changes"
say "  Theme"
info "Color scheme 'Empire Mist' (#101820 / #253846 / #B8D5E0) for Plasma and apps"
info "Plasma style 'Breeze' (follows the color scheme), application style Breeze, menus 100% opaque"
info "KWin: blur, background contrast, translucency, wobbly and magic lamp effects off; tiny borders; buttons I A X"
info "Konsole profile 'Empire Mist' as default (font: $MONO_FONT, no transparency)"
info "Wallpaper: untouched"
if [[ $DO_PANEL == 1 ]]; then
    say "  Top bar (${THICKNESS}px, opaque, not floating)"
    info "Arch menu │ I II III │ pinned apps │ music      clock      tray │ ${KB_LABEL} BT Wi-Fi Vol Notif ⏻"
    if [[ $REPLACE_PANELS == 1 && $PANEL_COUNT -gt 0 ]]; then
        info "Removes your $PANEL_COUNT current panel(s), dock included (asked separately, backed up)"
    fi
fi
[[ $DO_DESKTOPS == 1 ]] && say "  Virtual desktops" && info "Exactly 3: I Dark Age · II Feudal Age · III Castle Age (now: $DESKTOP_COUNT)"
if [[ $DO_KEYBOARD == 1 ]]; then
    say "  Keyboard"
    if [[ -z $KB_CURRENT ]]; then info "Layouts ${KB_LABEL} (click the indicator to switch)"; else info "Keeps your layouts ($KB_CURRENT); only the labels become ${KB_LABEL}"; fi
fi
[[ $DO_SHELL == 1 ]] && say "  Shell" && info "Minimal prompt  Λ ~/dir ›  for $LOGIN_SHELL (one marked block in its rc file)"
say "  Not touched: kernel, drivers, Steam, Proton, Gamescope, OBS, power settings, boot, services, icons, fonts, wallpaper"

if [[ $DRY_RUN == 1 ]]; then
    step "Dry run: nothing was changed."
    exit 0
fi

ask "Apply these changes?" n || { say "  Nothing changed."; exit 0; }

if [[ $DO_PANEL == 1 && $REPLACE_PANELS == 1 && $PANEL_COUNT -gt 0 ]]; then
    if ! ask "Remove your current $PANEL_COUNT panel(s) and replace them with the Empire bar?" n; then
        if ask "Add the Empire bar next to your current panels instead?" y; then
            REPLACE_PANELS=0
        else
            DO_PANEL=0
        fi
    fi
fi

KB_WRITE_LIST=0
if [[ $DO_KEYBOARD == 1 && -z $KB_CURRENT ]]; then
    ask "Configure keyboard layouts ${KB_LABEL}?" y && KB_WRITE_LIST=1
fi

if [[ $DO_DESKTOPS == 1 && $DESKTOP_COUNT =~ ^[0-9]+$ && $DESKTOP_COUNT -gt 3 ]]; then
    ask "You have $DESKTOP_COUNT desktops; remove the extra ones (their windows move to another desktop)?" n || DO_DESKTOPS=0
fi

SHELLS=()
if [[ $DO_SHELL == 1 ]]; then
    case $LOGIN_SHELL in
        bash|zsh|fish) SHELLS+=("$LOGIN_SHELL") ;;
        *) warn "Login shell '$LOGIN_SHELL' has no Empire prompt; skipping." ;;
    esac
    for other in bash zsh fish; do
        [[ $other == "$LOGIN_SHELL" ]] && continue
        case $other in
            bash) rc="$HOME/.bashrc" ;;
            zsh) rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
            fish) rc="$CONFIG_HOME/fish/config.fish" ;;
        esac
        if [[ -f $rc ]] && ask "Also add the prompt to $other ($rc)?" n; then SHELLS+=("$other"); fi
    done
fi

# ════════════════════════════════════════════════════════════════════════
# 3. Backup
# ════════════════════════════════════════════════════════════════════════
step "Backing up"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$EMPIRE_BACKUPS/$STAMP"
mkdir -p "$BACKUP/files"
: > "$BACKUP/files.list"
: > "$BACKUP/keys.tsv"

backup_file() {  # path relative to $HOME
    local rel=$1
    grep -qxF "$rel" "$BACKUP/files.list" && return 0
    printf '%s\n' "$rel" >> "$BACKUP/files.list"
    if [[ -e "$HOME/$rel" ]]; then
        mkdir -p "$BACKUP/files/$(dirname "$rel")"
        cp -a "$HOME/$rel" "$BACKUP/files/$rel"
    else
        printf '%s\n' "$rel" >> "$BACKUP/absent.list"
    fi
}

cfg_rel() { local p="$CONFIG_HOME/$1"; printf '%s' "${p#"$HOME"/}"; }

for f in kdeglobals kwinrc breezerc plasmarc konsolerc kxkbrc plasmashellrc \
         plasma-org.kde.plasma.desktop-appletsrc; do
    backup_file "$(cfg_rel "$f")"
done
for s in "${SHELLS[@]}"; do
    case $s in
        bash) backup_file ".bashrc" ;;
        zsh) backup_file "$(r="${ZDOTDIR:-$HOME}/.zshrc"; printf '%s' "${r#"$HOME"/}")" ;;
        fish) backup_file "$(cfg_rel fish/config.fish)" ;;
    esac
done

{
    printf 'STAMP=%q\n' "$STAMP"
    printf 'PLASMA_VERSION=%q\n' "$PLASMA_VERSION"
    printf 'COLOR_SCHEME=%q\n' "$CUR_SCHEME"
    printf 'DESKTOP_THEME=%q\n' "$CUR_THEME"
    printf 'PANEL_CHANGED=%q\n' "$DO_PANEL"
    printf 'DESKTOPS_CHANGED=%q\n' "$DO_DESKTOPS"
    printf 'DESKTOP_NAMES=('
    if [[ $DO_DESKTOPS == 1 ]]; then
        while IFS=$'\t' read -r _ name; do printf '%q ' "$name"; done < <(kwin_desktops)
    fi
    printf ')\n'
    printf 'SHELLS=(%s)\n' "${SHELLS[*]}"
} > "$BACKUP/state"

# Record a key's current value (once per backup) before changing it.
set_key() {  # file group key value
    local file=$1 group=$2 key=$3 value=$4 old
    if ! grep -qF "$file"$'\t'"$group"$'\t'"$key"$'\t' "$BACKUP/keys.tsv"; then
        old=$(kread "$file" "$group" "$key")
        printf '%s\t%s\t%s\t%s\n' "$file" "$group" "$key" "$old" >> "$BACKUP/keys.tsv"
    fi
    kwrite "$file" "$group" "$key" "$value"
}

[[ -L $EMPIRE_ORIGINAL ]] || ln -s "$BACKUP" "$EMPIRE_ORIGINAL"
ok "Backup: $BACKUP"

# ════════════════════════════════════════════════════════════════════════
# 4. Apply
# ════════════════════════════════════════════════════════════════════════
INSTALLED="$EMPIRE_HOME/installed.list"
touch "$INSTALLED"
track() { grep -qxF "$1" "$INSTALLED" || printf '%s\n' "$1" >> "$INSTALLED"; }

step "Installing assets"
mkdir -p "$EMPIRE_HOME" "$DATA_HOME/color-schemes" "$DATA_HOME/konsole" "$DATA_HOME/plasma/plasmoids" "$CONFIG_HOME/empire-plasma"

cp "$REPO_DIR/assets/empire-arch.svg" "$EMPIRE_HOME/empire-arch.svg"
track "$EMPIRE_HOME/empire-arch.svg"

cp "$REPO_DIR/config/color-schemes/EmpireMist.colors" "$DATA_HOME/color-schemes/"
track "$DATA_HOME/color-schemes/EmpireMist.colors"

cp "$REPO_DIR/config/konsole/EmpireMist.colorscheme" "$DATA_HOME/konsole/"
sed "s/@EMPIRE_MONO_FONT@/$MONO_FONT/" "$REPO_DIR/config/konsole/EmpireMist.profile" > "$DATA_HOME/konsole/EmpireMist.profile"
track "$DATA_HOME/konsole/EmpireMist.colorscheme"
track "$DATA_HOME/konsole/EmpireMist.profile"

for pkg in "$REPO_DIR"/plasma/plasmoids/*/; do
    id=$(basename "$pkg")
    rm -rf "$DATA_HOME/plasma/plasmoids/$id"
    cp -r "$pkg" "$DATA_HOME/plasma/plasmoids/$id"
    track "$DATA_HOME/plasma/plasmoids/$id"
done
ok "Color scheme, Konsole profile, Arch icon and $(find "$REPO_DIR/plasma/plasmoids" -mindepth 1 -maxdepth 1 -type d | wc -l) widgets copied"

step "Applying the theme"
plasma-apply-colorscheme EmpireMist >/dev/null
ok "Color scheme: Empire Mist"
if [[ $CUR_THEME != default ]]; then
    plasma-apply-desktoptheme default >/dev/null && ok "Plasma style: Breeze (follows the color scheme)"
fi
set_key kdeglobals KDE widgetStyle Breeze
set_key breezerc Style MenuOpacity 100
set_key breezerc Common ShadowSize ShadowSmall
set_key breezerc Common OutlineCloseButton false
set_key breezerc Windeco TitleAlignment AlignCenterFullWidth
set_key breezerc Windeco DrawBackgroundGradient false
set_key breezerc Windeco DrawBorderOnMaximizedWindows false
set_key kwinrc org.kde.kdecoration2 library org.kde.breeze
set_key kwinrc org.kde.kdecoration2 theme Breeze
set_key kwinrc org.kde.kdecoration2 BorderSize Tiny
set_key kwinrc org.kde.kdecoration2 BorderSizeAuto false
set_key kwinrc org.kde.kdecoration2 ButtonsOnLeft ""
set_key kwinrc org.kde.kdecoration2 ButtonsOnRight IAX
for effect in blur contrast translucency wobblywindows magiclamp; do
    set_key kwinrc Plugins "${effect}Enabled" false
done
kwin_reconfigure
ok "KWin: Breeze decoration, tiny borders, no blur / transparency effects"

set_key konsolerc "Desktop Entry" DefaultProfile EmpireMist.profile
ok "Konsole: Empire Mist profile is the default for new windows"

if [[ $DO_KEYBOARD == 1 ]]; then
    if [[ $KB_WRITE_LIST == 1 ]]; then
        set_key kxkbrc Layout LayoutList "$KB_TARGET"
        set_key kxkbrc Layout Use true
    fi
    if [[ $KB_WRITE_LIST == 1 || -n $KB_CURRENT ]]; then
        set_key kxkbrc Layout DisplayNames "${KB_TARGET^^}"
        ok "Keyboard: ${KB_LABEL}"
    fi
fi

if [[ $DO_DESKTOPS == 1 ]]; then
    kwin_set_desktops "${AGE_NAMES[@]}" >/dev/null
    ok "Virtual desktops: $(kwin_desktop_count) — $(kwin_desktops | cut -f2 | paste -sd',' - | sed 's/,/, /g')"
fi

for s in "${SHELLS[@]}"; do
    cp "$REPO_DIR/config/shell/prompt.$s" "$CONFIG_HOME/empire-plasma/prompt.$s"
    track "$CONFIG_HOME/empire-plasma/prompt.$s"
    case $s in
        bash) rc="$HOME/.bashrc"; line="[ -f \"$CONFIG_HOME/empire-plasma/prompt.bash\" ] && . \"$CONFIG_HOME/empire-plasma/prompt.bash\"" ;;
        zsh) rc="${ZDOTDIR:-$HOME}/.zshrc"; line="[[ -f \"$CONFIG_HOME/empire-plasma/prompt.zsh\" ]] && source \"$CONFIG_HOME/empire-plasma/prompt.zsh\"" ;;
        fish) rc="$CONFIG_HOME/fish/config.fish"; line="test -f \"$CONFIG_HOME/empire-plasma/prompt.fish\"; and source \"$CONFIG_HOME/empire-plasma/prompt.fish\"" ;;
    esac
    mkdir -p "$(dirname "$rc")"
    rc_remove_block "$rc"
    printf '\n%s\n%s\n%s\n' "$BLOCK_BEGIN" "$line" "$BLOCK_END" >> "$rc"
    ok "Prompt added to $rc (opens in new terminals)"
done

# ── Top bar ──────────────────────────────────────────────────────────────
PANEL_ID=""
if [[ $DO_PANEL == 1 ]]; then
    step "Building the top bar"
    SCRIPT=$(mktemp --suffix=.js)
    trap 'rm -f "$SCRIPT"' EXIT
    json_string() { local s=${1//\\/\\\\}; printf '"%s"' "${s//\"/\\\"}"; }
    sed_escape() { printf '%s' "$1" | sed -e 's/[|&\\]/\\&/g'; }
    sed -e "s|@THICKNESS@|$THICKNESS|" \
        -e "s|@KICKOFF_ICON@|$(sed_escape "$(json_string "$EMPIRE_HOME/empire-arch.svg")")|" \
        -e "s|@LAUNCHERS@|$(sed_escape "$LAUNCHERS_JSON")|" \
        -e "s|@WITH_BLUETOOTH@|$([[ $HAS_BLUETOOTH == 1 ]] && echo true || echo false)|" \
        -e "s|@REPLACE_PANELS@|$([[ $REPLACE_PANELS == 1 ]] && echo true || echo false)|" \
        "$REPO_DIR/plasma/layout/empire-panel.js" > "$SCRIPT"

    OUTPUT=$(plasma_eval "$SCRIPT") || die "Plasma rejected the layout script. Your backup is intact: ./restore.sh"
    PANEL_ID=$(grep -o 'EMPIRE_PANEL=[0-9]*' <<< "$OUTPUT" | cut -d= -f2)
    TRAY_ID=$(grep -o 'EMPIRE_TRAY=[0-9]*' <<< "$OUTPUT" | cut -d= -f2)
    while read -r skipped; do [[ -n $skipped ]] && warn "Widget not available, skipped: ${skipped#EMPIRE_SKIP=}"; done \
        < <(grep -o 'EMPIRE_SKIP=[A-Za-z0-9._-]*' <<< "$OUTPUT" || true)
    [[ -n $PANEL_ID ]] || die "The layout script did not report a panel. Output: $OUTPUT"
    ok "Panel $PANEL_ID created"

    # Persist the view settings and the tray configuration while plasmashell
    # is stopped, so nothing in memory can overwrite them.
    sleep 2
    plasmashell_stop
    VIEW="PlasmaViews>Panel $PANEL_ID"
    kwrite plasmashellrc "$VIEW" panelOpacity 1
    kwrite plasmashellrc "$VIEW" floating 0
    kwrite plasmashellrc "$VIEW" panelVisibility 0
    kwrite plasmashellrc "$VIEW>Defaults" thickness "$THICKNESS"

    # Same lists as TRAY_EXTRA / TRAY_HIDDEN / TRAY_KNOWN in plasma/layout/empire-panel.js — keep in sync.
    write_tray() {  # group-path
        kwrite "$APPLETSRC_NAME" "$1" extraItems "org.kde.plasma.devicenotifier,org.kde.plasma.cameraindicator,org.kde.kdeconnect,org.kde.plasma.clipboard,org.kde.plasma.mediacontroller,org.kde.plasma.battery"
        kwrite "$APPLETSRC_NAME" "$1" hiddenItems "org.kde.plasma.clipboard,org.kde.plasma.mediacontroller,org.kde.plasma.battery"
        kwrite "$APPLETSRC_NAME" "$1" knownItems "org.kde.plasma.keyboardlayout,org.kde.plasma.bluetooth,org.kde.plasma.networkmanagement,org.kde.plasma.volume,org.kde.plasma.notifications,org.kde.plasma.devicenotifier,org.kde.plasma.cameraindicator,org.kde.kdeconnect,org.kde.plasma.clipboard,org.kde.plasma.mediacontroller,org.kde.plasma.battery,org.kde.plasma.keyboardindicator,org.kde.plasma.manage-inputmethod,org.kde.plasma.printmanager,org.kde.plasma.vault,org.kde.plasma.weather,org.kde.plasma.brightness,org.kde.plasma.nightcolorcontrol,org.kde.plasma.nightlight,org.kde.kscreen,org.kde.plasma.colorpicker,org.kde.plasma.systemmonitor"
    }
    APPLETSRC_NAME=$(basename "$APPLETSRC")
    if [[ -n $TRAY_ID && $TRAY_ID != 0 ]]; then
        write_tray "Containments>$PANEL_ID>Applets>$TRAY_ID>Configuration>General"
    fi
    plasmashell_start

    # Plasma <= 6.3 creates the tray's inner containment only once the UI is
    # ready, so configure it after the first start.
    INNER=$(kread "$APPLETSRC_NAME" "Containments>$PANEL_ID>Applets>${TRAY_ID:-0}>Configuration" SystrayContainmentId)
    if [[ $INNER =~ ^[0-9]+$ && $INNER -gt 0 ]]; then
        sleep 2
        plasmashell_stop
        write_tray "Containments>$INNER>General"
        plasmashell_start
    fi
    ok "Bar saved: opaque, ${THICKNESS}px, not floating"
fi

# ════════════════════════════════════════════════════════════════════════
# 5. Verify what can be verified from a script
# ════════════════════════════════════════════════════════════════════════
step "Checking the result"
FAILS=0
check() {  # description, command...
    local what=$1; shift
    if "$@" >/dev/null 2>&1; then ok "$what"; else warn "FAILED: $what"; FAILS=$((FAILS + 1)); fi
}

check "color scheme is Empire Mist" test "$(kread kdeglobals General ColorScheme)" = EmpireMist
check "KWin blur is off" test "$(kread kwinrc Plugins blurEnabled)" = false
check "Konsole default profile set" test "$(kread konsolerc "Desktop Entry" DefaultProfile)" = EmpireMist.profile
[[ $DO_DESKTOPS == 1 ]] && check "exactly 3 virtual desktops" test "$(kwin_desktop_count)" = 3

if [[ -n $PANEL_ID ]]; then
    VERIFY=$(mktemp --suffix=.js)
    cat > "$VERIFY" <<EOF
const p = panelById($PANEL_ID);
if (p) {
    print("LOCATION=" + p.location);
    print("HEIGHT=" + p.height);
    print("OPACITY=" + p.opacity);
    print("FLOATING=" + p.floating);
    print("WIDGETS=" + p.widgets().map(w => w.type).join(","));
}
print("PANELS=" + panelIds.length);
EOF
    RESULT=$(plasma_eval "$VERIFY" || true)
    rm -f "$VERIFY"
    get() { grep -o "^$1=.*" <<< "$RESULT" | cut -d= -f2-; }
    check "bar is at the top" test "$(get LOCATION)" = top
    check "bar is ${THICKNESS}px thick" test "$(get HEIGHT)" = "$THICKNESS"
    if [[ -n $(get OPACITY) && $(get OPACITY) != undefined ]]; then
        check "bar is opaque" test "$(get OPACITY)" = opaque
    else
        check "bar is opaque (plasmashellrc)" test "$(kread plasmashellrc "PlasmaViews>Panel $PANEL_ID" panelOpacity)" = 1
    fi
    check "bar is not floating" test "$(get FLOATING)" = false
    WIDGETS=$(get WIDGETS)
    for w in org.kde.plasma.kickoff org.empire.mist.ages org.empire.mist.launchers org.empire.mist.media \
             org.empire.mist.clock org.kde.plasma.systemtray org.kde.plasma.keyboardlayout \
             org.kde.plasma.networkmanagement org.kde.plasma.volume org.kde.plasma.notifications org.empire.mist.power; do
        check "widget $w is in the bar" grep -q "$w" <<< "$WIDGETS"
    done
    if grep -qiE 'systemmonitor|weather|cpu|temperature' <<< "$WIDGETS"; then
        warn "FAILED: a monitoring widget is in the bar"; FAILS=$((FAILS + 1))
    else
        ok "no CPU / RAM / GPU / temperature / weather widgets"
    fi
    [[ $REPLACE_PANELS == 1 ]] && check "only one panel left" test "$(get PANELS)" = 1
fi

step "Done"
if (( FAILS > 0 )); then
    warn "$FAILS automatic check(s) failed — see above. Undo everything with ./restore.sh"
fi
say "  Still to check by eye (no script can see these): see 'Manual checklist' in README.md."
say "  Undo everything:  $REPO_DIR/restore.sh"
say "  Konsole windows that are already open keep their old profile; open a new one."
