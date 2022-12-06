#!/bin/bash
set -e

####################
#
# Adam Klein 20221206
#
# Update dynamic DNS hosted on domains.google.com
# Could possibly work with other providers, have not tried though
#
# Had issues with pfSense box updating DNS so I created this script to help facilitate this need and also makes adding domains easier with JSON file.
#
####################

## commands needed to run
REQUIREMENTS=("jq" "curl" "eval" "echo")

## Path to config file
CONFIG_FILE="config.json"

## Preflight checkes
## Verifies requirements are met
for app in ${REQUIREMENTS[*]}; do
        if [ ! $(command -v ${app}) ]; then
                echo "${app} is not installed. Please install ${app} and rerun $(basename ${0})."
                exit 1
        fi
done

## Test if config file exists, if not exit
if [ ! -f ${CONFIG_FILE} ]; then
        echo "${CONFIG_FILE} is missing."
        exit 1
fi

## Function to send notification of outcome
function send_notification() {
        local po_key=$(jq -r ".pushover_settings.key" ${CONFIG_FILE})
        local po_app=$(jq -r ".pushover_settings.app" ${CONFIG_FILE})
        local po_api_url=$(jq -r ".pushover_settings.api_url" ${CONFIG_FILE})

        local curl_cmd="curl -s -X POST ${po_api_url} --data-urlencode \"token=${po_app}\" --data-urlencode \"user=${po_key}\" --data-urlencode \"message=${*}\""
        local response=$(eval "${curl_cmd}")
        local r="${?}"
        if [[ $(echo ${response} | jq -r .status) -ne 1 ]]; then
                if [ -t 1 ]; then
                        echo -en "Error sending pushover notification. Please investigate.\r\n${response}"
                fi
        fi
        if [ "${r}" -ne 0 ]; then
                echo "${0}: Failed to send message" >&2
        fi

        return "${r}"
}

## Function to get current host address
function get_current_address() {
        current_address=$(curl -s ipaddr.io)
        if [ -t 1 ]; then
                echo "Current address is: ${current_address}"
        fi
}

## Function get to what Google DNS currently has for domain A Record
function get_current_dns() {
        current_dns=$(dig +short ${1} @8.8.8.8)
        if [ -t 1 ]; then
                echo "Current DNS is: ${current_dns}"
        fi
}

## Function to update Google Domain DNS
function update_google_dns() {
        local update_url=$(jq -r ".domain_settings.update_url" ${CONFIG_FILE})
        local update_header_host=$(jq -r ".domain_settings.update_header_host" ${CONFIG_FILE})

        local result=$(curl -s -X POST ${update_url} --data-urlencode "hostname=${1}" --data-urlencode "myip=${current_address}" -H "Host: ${update_header_host}" -u "${2}:${3}")
        case $(echo ${result} | awk '{print $1}') in
                "good")
                        send_notification "${1^^} address changed. New address is ${current_address}" ;;
                "nochg")
                        if [ -t 1 ]; then echo "No change to IP for ${1^^}"; fi ;;
                "badauth")
                        send_notification "Username/password provided for ${1^^} is not valid." ;;
                "nohost")
                        send_notification "${1^^} does not exists, or dynamic DNS is not enabled." ;;
                "notfqdn")
                        send_notification "${1^^} is not a valid fully-qualified domain name." ;;
                "badagent")
                        send_notification "You are making bad agent requests, or are making a request with IPV6 address (not supported)." ;;
                "abuse")
                        send_notification "Dynamic DNS access for ${1^^} has been blocked due to failure to interperet previous responses correctly." ;;
                "911")
                        if [ -t 1 ]; then echo "An error happened on Google's end. I will try again on next check."; fi ;;
                "*")
                        if [ -t 1 ]; then echo "I'm not sure how to interperet this result: ${result}"; fi ;;
        esac


}

## Function to compare current address with DNS. If they do not match attempt to update and send notification.
function compare_addresses() {
        get_current_address
        get_current_dns ${1}
        if [ "${current_address}" != "${current_dns}" ]; then
                update_google_dns ${1} ${2} ${3}
        elif [ "${current_address}" == "${current_dns}" ]; then
                if [ -t 1 ]; then
                        echo "Addresses are the same. No updating required"
                fi
                exit 0
        else
                echo "Error comparing addresses"
                exit 1
        fi
}

## Loop through config file for domains to test
function main() {
        for key in $(jq -r ".domains | keys | .[]" ${CONFIG_FILE}); do
                local domain=$(jq -r ".domains.${key}.domain" ${CONFIG_FILE})
                local username=$(jq -r ".domains.${key}.username" ${CONFIG_FILE})
                local password=$(jq -r ".domains.${key}.password" ${CONFIG_FILE})

                compare_addresses ${domain} ${username} ${password}
        done
}

## Run the script
main
