# Empire Mist prompt for fish (CachyOS default shell) — sourced from
# ~/.config/fish/config.fish by empire-plasma, after CachyOS' own config.
# Shape:  Λ ~/projects/aoe ›        on error:  Λ ~/projects/aoe ×127 ›

status is-interactive; or exit

function fish_prompt
    set -l code $status
    set_color B8D5E0
    printf 'Λ '
    set_color 86A0AC
    printf '%s' (prompt_pwd --full-length-dirs=2 2>/dev/null; or prompt_pwd)
    if test $code -ne 0
        set_color B8D5E0
        printf ' ×%s' $code
    end
    set_color B8D5E0
    printf ' › '
    set_color normal
end

function fish_right_prompt
end

function fish_mode_prompt
end
