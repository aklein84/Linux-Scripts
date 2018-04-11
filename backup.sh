#!/bin/sh

# Created by Adam Klein - 20180120.0213
# Usage: Creates snapshot of all VMs and transfer to file server via SCP. SSH public keys are utilized to initiate transfer.
# Can also pass a single VM name for a one-off snapshot

# TODO: 
	# In sanity_check function, add ability to ensure all variables are populated.
	# Use of pushover via wget not working. Busybox version of wget doesn't support '--post-data'. Implement python script to send notificaitons.

VERBOSE=true
DEBUG=true

SNAME="ESXi VM Snapshot Backup"							
SDESC="Create snapshot of all VMs and send to file server via SCP."
SCALL="sh ${0##*/}"
SPATH="/vmfs/volumes/datastore1/backups"
#SPATH="$PWD"
SLOG="${SPATH}/${0%.*}.log"

# Current date
CURR_DATE=$(date '+%Y%m%d')
# Current timestamp
TIMESTAMP=$(date '+%m/%d/%Y %H:%M:%S')

# Keeps tarball on server locally
KEEP_TAR=false

# Makes copy of VM folder
DO_BAK=false

# Copy tarball to SCP server
DO_SCP=true

# Send notifications
DO_NOTIFY=true

# VM folder location
SOURCE="/vmfs/volumes/datastore1"

# Backup folder location
BU_DIR="/vmfs/volumes/datastore1/backups"

# VM folder copy location. Only used if '$DO_BAK=true'
CP_DIR="${BU_DIR}/vm-raw-copy"
# Number of copies to keep
MAXCP=0

# Tarball folder location. Needed if $DO_SCP=true or $KEEP_TAR=true'
TB_DIR="${BU_DIR}/tarball-copy"
# Number of tarballs to keep
MAXTB=0

# SCP information. Using key exchange to make connection.  
SCP_CMD='/bin/scp'
SCP_SERVER=''
SCP_PORT=''
SCP_USER=''
DST_DIR=''

# Notifications via Pushover.net
PO_TOKEN=''
PO_USER=''

# Move contents of current job into history file
log_rotate() {
	if ! ${DEBUG}; then
		touch ${SLOG}
		touch ${SLOG}.history
		cat ${SLOG} >> ${SLOG}.history
		echo > ${SLOG}
	fi
}

# Entry entries to log file
write_log() {
	if ${VERBOSE} || ${DEBUG}; then
		echo -e ${1}
	fi
	if ! ${DEBUG}; then
		echo -e "[ "${TIMESTAMP}" ] ${1}" >> ${SLOG}
	fi
}

# Display information if $VERBOSE=true
display_info(){
	if ${VERBOSE} ; then
		clear
		echo '**********************************************************************'
		if ${DEBUG}; then
			echo -e "\r\n\tDEBUGGING: ${SNAME}\r\n\t${SDESC}"
		else
			echo -e "\r\n\t${SNAME}\r\n\t${SDESC}"
		fi
		echo -e "\r\n\tScript path: ${SPATH}\r\n\tScript call: ${SCALL}\r\n"
		echo -e "\tUsage: ${SCALL}\r\n\tOne off snapshot: ${SCALL} {VMNAME}\r\n"
		echo '**********************************************************************'
		echo
	fi
}

# Send notification via pushover.net
notify() {
	if ${DEBUG}; then
		write_log "\tDEBUG: notify function - ${@}"
	fi		

	if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${PO_TOKEN}" ] || [ -z "${PO_USER}" ]; then
		DO_NOTIFY=false
		write_log "\tNo parameters sent to notify function. No notifications will be sent"
	fi
	
	if ${DO_NOTIFY} ; then
		wget -q -O - \
		--post-data="token=${PO_TOKEN}&user=${PO_USER}&title=${1}&message=${2}" \
		'https://api.pushover.net/1/messages.json' >> /dev/null 2>&1
	fi
}

# Function to delete old backups. Retention based on $MAXTB and $MAXCP
delete_old_backups() {
	if [ -d ${1} ]; then
		BACKUP_COUNT=$(ls -d ${1}/* | wc -l)
		write_log "\tThere are [ ${BACKUP_COUNT} / ${2} ] ${4} backup(s) found in ${1}..."
		if ${3} ; then 			
			if [ ${BACKUP_COUNT} -gt ${2} ]; then
				OLD_BACKUPS=$(ls -dt ${1}/* | tail -1)
				if ! ${DEBUG}; then
					rm -r ${OLD_BACKUPS} >> ${LOG} 2>&1
				fi
				write_log "\t...oldest backup deleted: ${OLD_BACKUPS}"
			fi
		else
			if ! ${DEBUG}; then
				rm -r ${1}
			fi
			write_log "\t...removed all local backups from ${1}"
			
		fi
	fi
}

# Do the actual cleanup of old backups
cleanup_old_backups() {
	write_log "\tChecking for existing backups..."
	delete_old_backups ${TB_DIR} ${MAXTB} ${KEEP_TAR} "tarball"
	delete_old_backups ${CP_DIR} ${MAXCP} ${DO_BAK} "raw copy"
	echo
}

# Verify path to file server is opened.
test_server_path() {
	write_log "\tChecking if server ${1} is available"
	if nc -w5 -z ${1} ${2} &> /dev/null; then
		write_log "\tServer ${1} at port ${2} is opened"
	else
		write_log "\tCan't access server ${1} at port ${2}."
		notify "${SNAME} ERROR" "Can't access server ${1} at port ${2}."
		exit 1
	fi
}

# Make sure all our ducks are in a row
sanity_check() {
	if ! ${DO_BAK} && ! ${KEEP_TAR} && ! ${DO_SCP}; then
		write_log "\tNo retention method enabled."
		notify "${SNAME} ERROR" "No retention method set. Please enable tarballs, direct copies, or remote copies"
		exit 1
	fi

# TODO: Add checks against other variables. (if $DO_SCP check SCP variables are populated, etc.)

}

# Create snapshots	
vm_snapshot() {
	if [ -d "${SOURCE}/${1}" ]; then
	    if [ -e "${SOURCE}/${1}/${1}.vmx" ]; then
	        write_log "\tTaking snapshot of ${1}..."
			if ! ${DEBUG}; then
	            vim-cmd vmsvc/snapshot.removeall "${SOURCE}/${1}/${1}.vmx" > /dev/null 2>&1 #>> ${SLOG} 2>&1
    	        vim-cmd vmsvc/snapshot.create "${SOURCE}/${1}/${1}.vmx" "${CURR_DATE} Backup" "Auto-backup taken ${TIMESTAMP}" 0 > /dev/null 2>&1 #>> ${SLOG} 2>&1
			fi
            cd ${SOURCE}/
			if ! ${DEBUG}; then
	            mkdir -p "${CP_DIR}/${CURR_DATE}/${1}"
			fi
            write_log "\tCopying VM ${1} contents..."
			
			for VMFile in ${SOURCE}/${1}/*; do
				if [[ ! ${VMFile##*.} == *"~" ]] && [[ ! ${VMFile##*.} == "vswap" ]] && [[ ! ${VMFile##*.} == "vswp" ]] && [[ ! ${VMFile##*.} == "vmsn" ]] && [[ ! ${VMFile##*.} == "lck" ]] && [[ ! ${VMFile##*.} == "log" ]] ; then
					if ! ${DEBUG}; then
						cp ${VMFile} ${CP_DIR}/${CURR_DATE}/${1} >> ${SLOG} 2>&1
					fi
            	fi
            done

            if ${DO_SCP} || ${KEEP_TAR}; then
				mkdir -p ${TB_DIR}/${CURR_DATE}/${1}
	            cd ${CP_DIR}/${CURR_DATE}/${1}
                write_log "\tCompressing ${1} snapshot..."
				if ! ${DEBUG}; then
	                tar czvf ${TB_DIR}/${CURR_DATE}/${1}/${1}_${CURR_DATE}.tar.gz ./ #>> ${SLOG} 2>&1
				fi
            fi

            if ! ${DO_BAK}; then
				if ! ${DEBUG}; then
					rm -R "${CP_DIR}/${CURR_DATE}/${1}"
				fi
            fi

            write_log "\tRemoving ${1} snapshots..."
			if ! ${DEBUG}; then
	            vim-cmd vmsvc/snapshot.removeall "${SOURCE}/${1}/${1}.vmx" /dev/null 2>&1 #>> ${SLOG} 2>&1
			fi
            write_log "\t...Done - ${1} has been backed up"
            echo
        fi
   fi
}

# Send tarball to file server via SCP
secure_copy() {
	write_log "\tSending by SCP..."
	write_log "\tDisabling client firewall..."
	esxcli network firewall set --enabled false #>> ${SLOG} 2>&1
	test_server_path ${SCP_SERVER} ${SCP_PORT}
	for TB in $(ls ${TB_DIR}/${CURR_DATE}); do
		write_log "\tSending ${TB} via SCP..."
		cd ${SOURCE}
		if ! ${DEBUG}; then
			scp -P ${SCP_PORT} ${TB_DIR}/${CURR_DATE}/${TB}/${TB}_${CURR_DATE}.tar.gz ${SCP_USER}@${SCP_SERVER}:${DST_DIR} #>> ${SLOG} 2>&1
		fi
	done
	write_log "\tEnabling client firewall..."
	esxcli network firewall set --enabled true #>> ${SLOG} 2>&1
	echo
}

log_rotate

display_info

echo -e "****************************************" >> ${SLOG}
write_log "\tStarting backup script"
echo

sanity_check

for VM in $(ls ${SOURCE}); do
	if [ -z ${1} ] || [ ${1} = ${VM} ]; then
		vm_snapshot ${VM}
	fi
done

secure_copy

cleanup_old_backups

write_log "\t...Script Complete"
echo -e "****************************************" >> ${SLOG}

if [ -z ${1} ]; then
	if ${DEBUG}; then
		MSG="DEBUG: All VMs have been backed up."
	else
		MSG="All VMs have been backed up."
	fi
else
	if ${DEBUG}; then
		MSG="DEBUG: ${1} has been backed up."
	else	
		MSG="VM: ${1} has been backed up."
	fi
fi
notify "${SNAME} Success" "${MSG}"

exit 0
