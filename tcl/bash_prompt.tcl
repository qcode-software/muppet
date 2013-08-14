package provide muppet 1.0
package require qcode
namespace eval muppet {}

proc muppet::bash_prompt_script {} {
    return {
#!/bin/bash
function prompt() {
local       BLUE="\[\033[0;34m\]"
local        RED="\[\033[0;31m\]"
local  LIGHT_RED="\[\033[1;31m\]"
local      WHITE="\[\033[1;37m\]"
local LIGHT_GREY="\[\033[0;37m\]"

local GREY="\[\033[0;30m\]"
local GREEN="\[\033[0;32m\]"
local BROWN="\[\033[0;33m\]"
local PURPLE="\[\033[1;35m\]"
local CYAN="\[\033[0;36m\]"

local DARK_GREY="\[\033[1;30m\]"
local DARK_GREEN="\[\033[1;32m\]"
local DARK_CYAN="\[\033[1;36m\]"
local DARK_BLUE="\[\033[1;34m\]"
local DARK_RED="\[\033[1;31m\]"
local DARK_BROWN="\[\033[1;33m\]"

local NO_COLOR="\[\033[0m\]"
local BOLD="\[\033[1m\]"

case $TERM in
    xterm*)
        TITLEBAR='\[\033]0;\u@\h:\w\007\]'
        ;;
    *)
        TITLEBAR=""
        ;;
esac

case $ENVIRONMENT in 
    DEV*)
	ENV_COLOR=$GREEN
	;;
    TEST*)
	ENV_COLOR=$CYAN
	;;
    LIVE)
	ENV_COLOR=$DARK_RED
	;;
    PROD*)
	ENV_COLOR=$DARK_RED
	;;
    *)
	ENV_COLOR=$NO_COLOR
	;;
esac

PS1="${TITLEBAR}[\$(date +%H:%M)][$ENV_COLOR $ENVIRONMENT $NO_COLOR]\n[\u@\h:\w$NO_COLOR]\\$ "

PS2="> "
PS4='+ '
}
# run
prompt
}
}

proc muppet::bash_prompt_install {} {
    file_write /etc/bash_prompt [bash_prompt_script] 0644
}

