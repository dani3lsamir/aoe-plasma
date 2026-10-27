# Empire Mist prompt for Bash — sourced from ~/.bashrc by empire-plasma.
# Shape:  Λ ~/projects/aoe ›        on error:  Λ ~/projects/aoe ×127 ›
# Λ is plain Unicode (Greek capital lambda), present in every font: no Nerd Font needed.

case $- in *i*) ;; *) return ;; esac

if [[ $COLORTERM == truecolor || $COLORTERM == 24bit ]]; then
    __empire_mist=$'\e[38;2;184;213;224m'
    __empire_dim=$'\e[38;2;134;160;172m'
else
    __empire_mist=$'\e[38;5;152m'
    __empire_dim=$'\e[38;5;109m'
fi
__empire_reset=$'\e[0m'

PROMPT_DIRTRIM=3

__empire_prompt() {
    local code=$?
    local status=""
    (( code != 0 )) && status=" \[${__empire_mist}\]×${code}\[${__empire_reset}\]"
    PS1="\[${__empire_mist}\]Λ\[${__empire_reset}\] \[${__empire_dim}\]\w\[${__empire_reset}\]${status} \[${__empire_mist}\]›\[${__empire_reset}\] "
}

# Run first so $? still holds the exit code of the user's command.
# PROMPT_COMMAND may be a string or (bash >= 5.1) an array; keep whatever is there.
if [[ " ${PROMPT_COMMAND[*]} " != *__empire_prompt* ]]; then
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
        PROMPT_COMMAND=(__empire_prompt "${PROMPT_COMMAND[@]}")
    else
        # shellcheck disable=SC2128,SC2178  # string form of PROMPT_COMMAND
        PROMPT_COMMAND="__empire_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
    fi
fi
