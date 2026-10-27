# shellcheck shell=bash disable=SC2034  # variables are used by the sourcing scripts
# Shared helpers for install.sh and restore.sh. Sourced, never executed.

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
EMPIRE_HOME="$DATA_HOME/empire-plasma"          # installed assets + backups
EMPIRE_BACKUPS="$EMPIRE_HOME/backups"
EMPIRE_ORIGINAL="$EMPIRE_HOME/original"         # symlink → the pre-install backup
UNSET="__EMPIRE_UNSET__"
ASSUME_YES="${ASSUME_YES:-0}"

# ── output ────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    C_MIST=$'\e[38;2;184;213;224m'; C_DIM=$'\e[38;2;134;160;172m'
    C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
else
    C_MIST=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

say()     { printf '%s\n' "$*"; }
step()    { printf '\n%s%sΛ %s%s\n' "$C_BOLD" "$C_MIST" "$*" "$C_RESET"; }
info()    { printf '  %s·%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
ok()      { printf '  %s✓%s %s\n' "$C_MIST" "$C_RESET" "$*"; }
warn()    { printf '  %s!%s %s\n' "$C_BOLD" "$C_RESET" "$*" >&2; }
die()     { printf '\n%s✗ %s%s\n' "$C_BOLD" "$*" "$C_RESET" >&2; exit 1; }

# ask "question" [default y|n] → 0 for yes
ask() {
    local question=$1 default=${2:-n} answer hint="[y/N]"
    [[ $default == y ]] && hint="[Y/n]"
    if [[ $ASSUME_YES == 1 ]]; then
        info "$question $hint → yes (--yes)"
        return 0
    fi
    if [[ ! -t 0 ]]; then
        [[ $default == y ]]
        return
    fi
    read -r -p "  ? $question $hint " answer || answer=""
    answer=${answer:-$default}
    [[ $answer == [yYsS]* ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

# ── KConfig ───────────────────────────────────────────────────────────────
# Groups are written "Outer>Inner" for nested groups.
_group_args() {
    local IFS='>' part
    local -a parts
    read -r -a parts <<< "$1"
    for part in "${parts[@]}"; do
        printf '%s\0' --group "$part"
    done
}

kread() {  # kread file group key → value, or $UNSET when absent
    local file=$1 group=$2 key=$3
    local -a g
    mapfile -d '' g < <(_group_args "$group")
    kreadconfig6 --file "$file" "${g[@]}" --key "$key" --default "$UNSET"
}

kwrite() {  # kwrite file group key value   (notifies running apps)
    local file=$1 group=$2 key=$3 value=$4
    local -a g
    mapfile -d '' g < <(_group_args "$group")
    kwriteconfig6 --notify --file "$file" "${g[@]}" --key "$key" -- "$value"
}

kdelete() {
    local file=$1 group=$2 key=$3
    local -a g
    mapfile -d '' g < <(_group_args "$group")
    kwriteconfig6 --notify --file "$file" "${g[@]}" --key "$key" --delete
}

# ── D-Bus (busctl ships with systemd; no qdbus dependency) ─────────────────
plasma_eval() {  # plasma_eval <script-file> → script's print() output on stdout
    local script
    script=$(<"$1")
    busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "$script" \
        | sed -e 's/^s "//' -e 's/"$//' -e 's/\\n/\n/g'
}

plasmashell_running() {
    busctl --user status org.kde.plasmashell >/dev/null 2>&1
}

plasmashell_stop() {
    if plasmashell_running; then
        kquitapp6 plasmashell >/dev/null 2>&1 \
            || busctl --user call org.kde.plasmashell /MainApplication org.qtproject.Qt.QCoreApplication quit >/dev/null 2>&1 \
            || true
    fi
    local i
    for i in $(seq 1 50); do
        pgrep -u "$UID" -x plasmashell >/dev/null || return 0
        sleep 0.2
    done
    warn "plasmashell did not exit in 10 s"
    return 1
}

plasmashell_start() {
    if systemctl --user cat plasma-plasmashell.service >/dev/null 2>&1; then
        systemctl --user start plasma-plasmashell.service
    else
        (setsid plasmashell >/dev/null 2>&1 &)
    fi
    local i
    for i in $(seq 1 100); do
        plasmashell_running && { sleep 1; return 0; }
        sleep 0.2
    done
    warn "plasmashell did not come back within 20 s — start it with: systemctl --user start plasma-plasmashell"
    return 1
}

kwin_reconfigure() {
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
}

# Virtual desktops via KWin's D-Bus API: prints "id<TAB>name" per desktop.
kwin_desktops() {
    busctl --user get-property org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager desktops \
        | grep -o '"[^"]*"' | tr -d '"' | paste - -
}

kwin_desktop_count() {
    busctl --user get-property org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager count \
        | awk '{print $2}'
}

kwin_create_desktop() {  # position name
    busctl --user call org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager createDesktop us "$1" "$2"
}

kwin_remove_desktop() {  # id
    busctl --user call org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager removeDesktop s "$1"
}

kwin_rename_desktop() {  # id name
    busctl --user call org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager setDesktopName ss "$1" "$2"
}

# Set the desktop list to exactly the given names (adds/removes at the end).
kwin_set_desktops() {
    local -a names=("$@") ids=()
    local id count
    while IFS=$'\t' read -r id _; do ids+=("$id"); done < <(kwin_desktops)
    count=${#ids[@]}
    while (( count > ${#names[@]} )); do
        kwin_remove_desktop "${ids[count-1]}"
        count=$((count - 1))
    done
    while (( count < ${#names[@]} )); do
        kwin_create_desktop "$count" "${names[count]}"
        count=$((count + 1))
    done
    ids=()
    while IFS=$'\t' read -r id _; do ids+=("$id"); done < <(kwin_desktops)
    local i
    for i in "${!names[@]}"; do
        [[ -n ${ids[i]:-} ]] && kwin_rename_desktop "${ids[i]}" "${names[i]}"
    done
    busctl --user set-property org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager rows u 1 >/dev/null 2>&1 || true
}

# ── shell rc blocks ────────────────────────────────────────────────────────
BLOCK_BEGIN="# >>> empire-plasma prompt >>>"
BLOCK_END="# <<< empire-plasma prompt <<<"

rc_has_block() { [[ -f $1 ]] && grep -qF "$BLOCK_BEGIN" "$1"; }

rc_remove_block() {
    [[ -f $1 ]] || return 0
    local tmp
    tmp=$(mktemp)
    # Drops the block and the single blank line the installer puts before it.
    awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
        $0 == b { skip = 1; held = 0; next }
        $0 == e { skip = 0; next }
        skip { next }
        held { print ""; held = 0 }
        $0 == "" { held = 1; next }
        { print }
        END { if (held) print "" }
    ' "$1" > "$tmp"
    cat "$tmp" > "$1"
    rm -f "$tmp"
}
