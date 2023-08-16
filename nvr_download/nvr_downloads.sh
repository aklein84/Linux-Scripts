#!/bin/bash

##################################################
#
# Downloads the daily NVR recordings for a 24 hour period
# with the information provided from JSON config file.
#
# Downloads are in one hour increments but for some reason,
# there's an additional two minute clip that gets downloaded.
# Since file size is small could use file size comparison to filter out.
#
##################################################

## NVR Variables
HOST=""
HOST_USERNAME=""
HOST_PASSWORD=''
CAMERA_CHANNEL=
BASE_URL="https://${HOST:=127.0.0.1}/cgi-bin/api.cgi"
NVR="" ## Arbitrary to reference recordings later in dump directory

## Email notification variables
SENDER=""
RECIPIENT=""

## JSON config file for upcoming event
CONF_FILE="$(dirname ${0})/config.json"

## Video dump location
DUMP_DIR=""

## Print troubleshooting statements
DEBUG=true

## Create empty variable for token. Needs a value or will otherwise fail
TOKEN="null"

## Exit if config file is not found.
if [ ! -f "${CONF_FILE}" ]; then
    exit 1
fi

## Function to ensure storage directory structure exists
function check_directory_structure() {
    EVENTNAME=$(jq -r '.upcoming_event.event_name' "${CONF_FILE}")
    STARTDATE=$(jq -r '.upcoming_event.start_date' "${CONF_FILE}")
    ENDDATE=$(jq -r '.upcoming_event.end_date' "${CONF_FILE}")

    ROOT_DIR="${DUMP_DIR}/${NVR:=REOLINK}/${STARTDATE:0:4}"
    EVENT_DIR="${ROOT_DIR}/${EVENTNAME}_${STARTDATE}-${ENDDATE}"

    if [ ! -d "${ROOT_DIR}" ]; then
        mkdir "${ROOT_DIR}"
        echo "${ROOT_DIR} exists"
    fi

    if [ ! -d "${EVENT_DIR}" ]; then
        mkdir "${EVENT_DIR}"
        echo "${EVENT_DIR} exists"
    fi
}

## Function to run commands against Reolink device
function run_command() {
    local cmd="${1}" param='{}'

    if [ -n "${2}" ]; then
        param="$(jq -n "${2}")"
    fi

    local request_data="$(jq -n --arg CMD "${cmd}" --argjson PARAM "${param}" '{ cmd: $CMD, action: 0, param: $PARAM, }')"

    local uri="${BASE_URL}?cmd=${cmd}&token=${TOKEN}"

    if ${DEBUG}; then
        echo ">>> REQUEST SENT >>>" 1>&2
        echo "URI: ${uri}" 1>&2
        jq -C . <<<"${request_data}" 1>&2
    fi

    local result="$(curl -kfsSLH "Content-Type: application/json" -X POST -d "[${request_data}]" "${uri}" | jq '.[0]' )"

    if ${DEBUG}; then
        echo "<<< RESPONSE RECEIVED <<<" 1>&2
        jq -C . <<<"${result}" 1>&2
    fi

    if [ "$(jq -r '.code' <<<"${result}")" -eq "0" ]; then
        jq '.value' <<<"${result}"
        return 0
    else
        echo -n "${cmd} ERROR: " 1>&2
        jq -r '"\(.error.detail) (\(.error.rspCode))"' <<< "${result}" 1>&2
    exit 1
  fi
}

## Function to obtain session token
function get_auth_token() {
    local USERNAME="${1}" PASSWORD="${2}"
    run_command Login "$(jq -n --arg USER "${USERNAME}" --arg PASS "${PASSWORD}" '{ User: { Version: 0, USERNAME: $USER, PASSWORD: $PASS }}')" | jq -r '.Token.name'
}

## Function to destroy session token
function api_logout() {
    if [ "${TOKEN}" = "null" ] || [ "${TOKEN}" == "" ]; then
        return
    fi

    run_command Logout > /dev/null
}

## Function to return available recordings during set timeframe and download them to output directory.
function download_recordings() {
    local dl_date=$(date --date="-1 day" +'%Y%m%d')

    if [ "${dl_date}" -lt "${STARTDATE}" ] || [ "${dl_date}" -gt "${ENDDATE}" ]; then
        exit
    fi

    local dl_year="${dl_date:0:4}"
    local dl_mon="${dl_date:4:2}"
    local dl_day="${dl_date:6:2}"
    local start_min=00
    local start_sec=00
    local end_min=59
    local end_sec=59
    local logfile="$(mktemp).txt"

    for i in {0..23}; do
        local start_hour="${i}"
        local end_hour="${i}"

        TOKEN=$(get_auth_token ${HOST_USERNAME} "${HOST_PASSWORD}")
        if [ -z "${TOKEN}" ]; then
            exit 1
        fi
        trap 'api_logout' EXIT

        files=$(run_command NvrDownload '{"NvrDownload": {"channel": '"${CAMERA_CHANNEL}"', "iLogicChannel" : 0, "streamType": "sub", "StartTime": { "year": '"${dl_year}"', "mon": '"${dl_mon}"', "day": '"${dl_day}"', "hour": '"${start_hour}"', "min": '"${start_min}"', "sec": '"${start_sec}"'}, "EndTime": { "year": '"${dl_year}"', "mon": '"${dl_mon}"', "day": '"${dl_day}"', "hour": '"${end_hour}"', "min": '"${end_min}"', "sec": '"${end_sec}"' } } }' )

        length=$(echo $files | jq -r .fileCount)

        #echo $files

        for ((x=0; x<${length}; x++)); do
            filename=$(echo ${files} | jq -r ".fileList[${x}].fileName")
            t_fname=$(echo "${filename}" | cut -d_ -f4)
            t_fname="${t_fname%.*}"
            year=${t_fname:0:4}
            month=${t_fname:4:2}
            day=${t_fname:6:2}
            time=${t_fname:8}
            out_filename="${month}-${day}-${year}_${time}.mp4"

            echo "${EVENT_DIR}/${t_fname:0:8}/${out_filename}"

            if [ ! -d "${EVENT_DIR}/${t_fname:0:8}" ]; then
                mkdir "${EVENT_DIR}/${t_fname:0:8}"
            fi

            echo "File ${filename} will be downloaded as: ${EVENT_DIR}/${t_fname:0:8}/${out_filename}" >> ${logfile}

            wget --no-check-certificate -O "${EVENT_DIR}/${t_fname:0:8}/${out_filename}" \
               "${BASE_URL}?cmd=Download&token=${TOKEN}&source=${filename}&output=${filename}"
        done
    done

    echo | mail -s "NVR Download for ${t_fname:0:8}" -A "${logfile}" -r "${SENDER}" "${RECIPIENT}"
    rm -f "${logfile}"
}

check_directory_structure
download_recordings
