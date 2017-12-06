#!/bin/bash

# Created by Adam Klein 20171206
# I put this script in /etc/cron.daily to be ran daily.
# Used in conjunction with iptables. Add below lines to firewall script
### Drop requests from banned IPs
	# iptables -I INPUT -m set --match-set blacklist2 src -j DROP
	# iptables -I OUTPUT -m set --match-set blacklist2 src -j DROP
	# iptables -I FORWARD -m set --match-set blacklist2 src -j DROP
	
# Relys on ipset, bc, iptables and pushover.sh

# Create new set using command below 
# ipset create <set name> hash:ip 

# If script is manually triggered provide feedback. If ran from cronjob no feedback is provided.
# I prefer feedback on scripts while running. To disable, change below variable, VERBOSE=1, to VERBOSE=0.
if [ -t 0 ]; then
   VERBOSE=1
else
   VERBOSE=0
fi

PUSHOVER=$(which pushover)					                # Pushover script take from: https://github.com/jnwatts/pushover.sh
TOKEN=                                      				# pushver.net api token
URL="https://lists.blocklist.de/lists/all.txt"			# URL hosting list of banned IPs
BANFILE="/etc/default/firewall.banned"				      # Location of banned list on local machine
OUTFILE="/tmp/firewall.banned.tmp"				          # Temp file name to compare downloaded list and current list

# Function to download banned list. If there's a failure, sends notification via Pushover
function download-list() {
	wget -qO $OUTFILE $URL
	if [ $? -ne 0 ]; then
		$PUSHOVER -T "$TOKEN" -t "$0" "Downloading new list failed. Please investigate"
		exit
	fi
}

# Updates blacklist for use with iptables.
function update-banned-list() {
	if [ -f "$BANFILE" ]; then
        COUNT=$(cat "$BANFILE" | wc -l)	
        let x=0
        echo

        while read BANNED; do
                ipset -q test blacklist2 $BANNED
                if [ "$?" -eq '1' ]; then
                	ipset add blacklist2 $BANNED
                fi
                if [ $VERBOSE -eq 1 ]; then
    	            x=$((x+1))
	                PERCENT=$(bc <<< "scale = 3; (( $x / $COUNT ) * 100)" )
                	tput setaf 2; echo -en "\rAdding banned IPs to firewall: $PERCENT %"
                fi
        done < /etc/default/firewall.banned

        if [ $VERBOSE -eq 1 ]; then
                tput sgr 0; echo -e "\nFirewall: Banned addresses added to IP set \"blacklist2\""
		echo
        fi
	else
	       echo "Firewall: Banned address list not found..."
	fi
}

download-list
CURLIST_HASH=$(sha512sum $BANFILE | awk '{print $1}')
NEWLIST_HASH=$(sha512sum $OUTFILE | awk '{print $1}')

if [ $NEWLIST_HASH == $CURLIST_HASH ]; then
	if [ $VERBOSE -eq 1 ]; then
		echo "No updates for banned list"
	fi
	rm $OUTFILE
else
	mv $OUTFILE $BANFILE
	if [ $VERBOSE -eq 1 ]; then
		echo "Updating banned list"
	fi
	update-banned-list	
	$PUSHOVER -T "$TOKEN" -t "$0" "Successfully updated banned list."
fi
