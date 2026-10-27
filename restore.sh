#!/usr/bin/env bash
# Empire Plasma — restore the desktop exactly as it was before ./install.sh.
#
#   ./restore.sh                 restore the original (first) backup
#   ./restore.sh --from DIR      restore a specific backup directory
#   ./restore.sh --list          list backups
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

FROM=""
while (( $# )); do
    case $1 in
        --from) FROM=${2:?--from needs a directory}; shift ;;
        --list) ls -1 "$EMPIRE_BACKUPS" 2>/dev/null || say "No backups."; exit 0 ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

(( EUID != 0 )) || die "Run as your normal user, not root."
for cmd in kwriteconfig6 kreadconfig6 busctl kquitapp6 plasma-apply-colorscheme plasma-apply-desktoptheme; do
    have "$cmd" || die "Missing '$cmd'."
done

if [[ -z $FROM ]]; then
    [[ -L $EMPIRE_ORIGINAL ]] || die "No Empire Plasma backup found in $EMPIRE_HOME."
    FROM=$(readlink -f "$EMPIRE_ORIGINAL")
fi
[[ -f $FROM/state && -f $FROM/files.list ]] || die "$FROM is not an Empire Plasma backup."

# shellcheck source=/dev/null
source "$FROM/state"

step "Restoring from $FROM"
info "Config files: $(paste -sd' ' "$FROM/files.list")"
info "Single keys changed by the installer: $(wc -l < "$FROM/keys.tsv")"
ask "Restore your previous desktop now? Plasma will restart for a moment." n || { say "  Nothing changed."; exit 0; }

# 1. Whole files (panels, plasmashellrc, shell rc files) — plasmashell must be
#    stopped, otherwise it writes its in-memory layout back on exit.
plasmashell_stop || true

KEYED_FILES=" kdeglobals kwinrc breezerc plasmarc konsolerc kxkbrc "
while IFS= read -r rel; do
    [[ -n $rel ]] || continue
    name=$(basename "$rel")
    # Files the installer changed key-by-key are restored key-by-key below,
    # so later edits you made to other keys survive.
    [[ $KEYED_FILES == *" $name "* ]] && continue
    case $name in
        .bashrc|.zshrc|config.fish)
            # Only the marked block was added; remove just that.
            rc_remove_block "$HOME/$rel"
            if grep -qxF "$rel" "$FROM/absent.list" 2>/dev/null && ! grep -q '[^[:space:]]' "$HOME/$rel" 2>/dev/null; then
                rm -f "$HOME/$rel"
            fi
            ok "Removed the prompt block from ~/$rel"
            continue ;;
    esac
    if [[ -e "$FROM/files/$rel" ]]; then
        mkdir -p "$(dirname "$HOME/$rel")"
        cp -a "$FROM/files/$rel" "$HOME/$rel"
        ok "Restored ~/$rel"
    elif grep -qxF "$rel" "$FROM/absent.list" 2>/dev/null; then
        rm -f "$HOME/$rel"
        ok "Removed ~/$rel (it did not exist before)"
    fi
done < "$FROM/files.list"

# 2. Individual keys.
while IFS=$'\t' read -r file group key old; do
    [[ -n $file ]] || continue
    if [[ $old == "$UNSET" ]]; then
        kdelete "$file" "$group" "$key"
    else
        kwrite "$file" "$group" "$key" "$old"
    fi
done < "$FROM/keys.tsv"
ok "Restored KWin, Breeze, Konsole and keyboard settings"

# 3. Color scheme and Plasma style (these tools also notify running apps).
if [[ $COLOR_SCHEME == "$UNSET" || -z $COLOR_SCHEME ]]; then
    COLOR_SCHEME=BreezeLight
fi
if plasma-apply-colorscheme "$COLOR_SCHEME" >/dev/null 2>&1; then
    ok "Color scheme: $COLOR_SCHEME"
else
    # The old scheme may have existed only inside kdeglobals: put that file back whole.
    KDEGLOBALS_REL=$(grep -m1 '/kdeglobals$' "$FROM/files.list" || true)
    if [[ -n $KDEGLOBALS_REL && -e "$FROM/files/$KDEGLOBALS_REL" ]]; then
        cp -a "$FROM/files/$KDEGLOBALS_REL" "$HOME/$KDEGLOBALS_REL"
        warn "Color scheme '$COLOR_SCHEME' is not installed as a file; restored the whole kdeglobals instead."
    else
        warn "Could not re-apply color scheme '$COLOR_SCHEME' — pick one in System Settings → Colors."
    fi
fi
THEME_WAS_UNSET=0
if [[ $DESKTOP_THEME == "$UNSET" || -z $DESKTOP_THEME ]]; then
    DESKTOP_THEME=default
    THEME_WAS_UNSET=1
fi
plasma-apply-desktoptheme "$DESKTOP_THEME" >/dev/null 2>&1 && ok "Plasma style: $DESKTOP_THEME" || true
(( THEME_WAS_UNSET )) && kdelete plasmarc Theme name

# 4. Virtual desktops.
if [[ ${DESKTOPS_CHANGED:-0} == 1 && ${#DESKTOP_NAMES[@]} -gt 0 ]]; then
    kwin_set_desktops "${DESKTOP_NAMES[@]}" >/dev/null && ok "Virtual desktops: ${#DESKTOP_NAMES[@]}"
fi

# 5. Installed assets.
if [[ -f $EMPIRE_HOME/installed.list ]]; then
    while IFS= read -r path; do
        [[ -n $path && $path == "$HOME"/* ]] || continue
        rm -rf -- "$path"
        # Drop folders the installer created, if they are now empty.
        rmdir -p --ignore-fail-on-non-empty "$(dirname "$path")" 2>/dev/null || true
    done < "$EMPIRE_HOME/installed.list"
    rm -f "$EMPIRE_HOME/installed.list"
    ok "Removed Empire widgets, color scheme, Konsole profile and prompt files"
fi

# Config files that did not exist before and now hold no settings.
while IFS= read -r rel; do
    [[ -n $rel && -f $HOME/$rel ]] || continue
    grep -q '=' "$HOME/$rel" || rm -f "$HOME/$rel"
done < <(cat "$FROM/absent.list" 2>/dev/null || true)

kwin_reconfigure
plasmashell_start || true

rm -f "$EMPIRE_ORIGINAL"
step "Restored. Backups are kept in $EMPIRE_BACKUPS (delete them when you no longer need them)."
say "  Open a new terminal to get your old prompt back."
