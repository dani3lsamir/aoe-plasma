# Empire Mist prompt for Zsh — sourced from ~/.zshrc by empire-plasma.
# Shape:  Λ ~/projects/aoe ›        on error:  Λ ~/projects/aoe ×127 ›

[[ -o interactive ]] || return 0

if [[ $COLORTERM == (truecolor|24bit) ]]; then
    typeset -g __empire_mist='#B8D5E0' __empire_dim='#86A0AC'
else
    typeset -g __empire_mist='152' __empire_dim='109'
fi

setopt PROMPT_PERCENT
PROMPT="%F{${__empire_mist}}Λ%f %F{${__empire_dim}}%3~%f%(?.. %F{${__empire_mist}}×%?%f) %F{${__empire_mist}}›%f "
RPROMPT=''
