#!/bin/bash

## Send notifications to Telegram
TELEGRAM=true

## Address of power strip
URL="127.0.0.1/cm"

## Add some color to menu
GREEN='\e[32m'
BLUE='\e[34m'
RED='\e[31m'
RESET='\e[0m'

## Functions
function ColorGreen() {
        echo -ne ${GREEN}${1}${RESET}
}
function ColorBlue() {
        echo -ne ${BLUE}${1}${RESET}
}

function ColorRed() {
    echo -ne ${RED}${1}${RESET}
}

function WebHook() {
    curl -s "${URL}?cmnd=${1}%20${2}" 2>&1>/dev/null
}

function PoststatustoTelegram() {
    if [ "${TELEGRAM}" != true ]; then
        return
    fi
    local chat_id=''
    local bot_id=''
    local outlet=${1^^}
    local results=$(curl -s "${URL}?cmnd=state" | jq -r ".${outlet}" )
    local json_data=$(jq -n --arg cid "${chat_id}" \
        --arg txt "Outlet ${outlet/POWER/} has been powered *${results}*
            [Control Panel](${URL/cm/})" \
        --arg dis_not "false" \
        --arg parse "MarkdownV2" \
        '{chat_id: $cid, text: $txt, disable_notification: $dis_not, parse_mode: $parse}' )
    curl -s -X POST -H "Content-Type: application/json" -d "${json_data}" "https://api.telegram.org/bot${bot_id}/sendMessage" 2>&1>/dev/null
}


function outlet_selection() {
echo -en "
Select outlet:
$(ColorGreen '1)') Outlet 1 - Desk Fan
$(ColorGreen '2)') Outlet 2
$(ColorGreen '3)') Outlet 3
$(ColorGreen '4)') USB
$(ColorGreen '0)') Exit
$(ColorBlue 'Choose an option:') "

    read outlet_select
    case ${outlet_select} in
        1) name="Desk Fan"; outlet='Power1'; power_selection ;;
        2) name="Outlet 2"; outlet='Power2'; power_selection ;;
        3) name="Outlet 3"; outlet='Power3'; power_selection ;;
        4) name="USB"; outlet='Power4'; power_selection ;;
        0) exit 0 ;;
        *) echo; echo -e $(ColorRed "Incorrect option. Please change your selection."); outlet_selection ;;
    esac
}

function power_selection() {
echo -en "
${name} - Power on/off:
$(ColorGreen '1)') Power On
$(ColorGreen '2)') Power Off
$(ColorGreen '5)') Select outlet
$(ColorGreen '0)') Exit
$(ColorBlue 'Choose an option:') "

    read power_select
    case ${power_select} in
        1) $(WebHook "${outlet}" "On"); $(PoststatustoTelegram ${outlet}); exit 0 ;;
        2) $(WebHook "${outlet}" "Off"); $(PoststatustoTelegram ${outlet}); exit 0 ;;
        5) outlet_selection ;;
        0) exit 0 ;;
        *) echo; echo -e $(ColorRed "Incorrect option. Please change your selection."); power_selection ;;
    esac
}

if [ ${#} -eq 2 ]; then
    $(WebHook "Power${1}" "${2}")
    $(PoststatustoTelegram "Power${1}")
    exit
fi

outlet_selection
