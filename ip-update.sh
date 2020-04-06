#/bin/bash

DNS_RECURSORS_LIST="8.8.8.8 208.67.222.222"
WORKDIR="/opt/workdir"
LOGFILE="${WORKDIR}/log"
NEW_IP_LIST_DIR="${WORKDIR}/ip-list"
DOMAIN_LIST="$@"
IP_LIST_CURRENT=""
IP_LIST=""
LOCK_FILE="/tmp/ip-update-lock"

#Check if domain list is not empty.
if [[ $# -eq 0 ]]; then
	echo -e "[ERROR]\t Usage: ./ip-update.sh example.com 2xample.com"
	exit 1
fi


#Check if work files and directories exist.
[ ! -d ${WORKDIR} ] && mkdir -p ${WORKDIR}
[ ! -d ${NEW_IP_LIST_DIR} ] && mkdir ${NEW_IP_LIST_DIR}
[ ! -f ${LOGFILE} ] && touch ${LOGFILE}


#Function for clear work dirs and exit script.
exit_script () {
	rm -f ${LOCK_FILE}
	exit 1
	kill -9 $$
}

#Function for logging.
log () {
	echo -e "$(date +%d/%m/%Y:%H:%M:%S) $@" >> $LOGFILE
}

log "Script started"

#Double run protection
if [ -f ${LOCK_FILE} ]; then
	echo "Script already running"
	log "[DOUBLE_RUN] Previous instance of script not finished"
	exit_script
else
	touch ${LOCK_FILE}
fi

#Function for checking dig return code and dig status.
dig_checker () {
DIG_RETURN_CODE=$?
DIG_OUTPUT=$1
DIG_STATUS=$(echo "${DIG_OUTPUT}" | grep -Eo 'status: [A-Z]+?')
RESOLVER=$(echo "${DIG_OUTPUT}" | grep -Eo ' [A-Za-z0-9]+?\.[A-Z0-9a-z]+?\.[A-Za-z0-9]+?\. ')
if [[ $(echo "${DIG_OUTPUT}" | awk '(/^[^;;]/) {print $NF}' | wc -l) -eq 0 ]]; then
	log "[ERROR] Dig finished with code "${DIG_RETURN_CODE}" and "${DIG_STATUS}", received empty list of DNS records"
	exit_script
elif [[ "${DIG_RETURN_CODE}" -ne 0 || "${DIG_STATUS}" != "status: NOERROR" ]]; then
	log "[ERROR] Dig finished with code ${DIG_RETURN_CODE} and ${DIG_STATUS} resolved by ${RESOLVER}"
	exit_script
else
	echo ${DIG_OUTPUT}
fi
}


#Function for getting authoritaive DNS servers for 2nd level domain.
get_main_dns () {
DOMAIN=$1
ZONE=$(echo $1 | grep -Eo '[A-Za-z0-9]+?\.[A-Za-z]+?$')
DIG_CHECK_STATUS=$(dig_checker "$(dig ${ZONE} ns)")
MAIN_DNS=$(echo "${DIG_CHECK_STATUS}" | grep -Eo ' [A-Za-z0-9]+?\.[A-Z0-9a-z]+?\.[A-Za-z0-9]+?\. ' | shuf -n2 | sort)
log "Founded authoritative NS servers for ${DOMAIN} \n$MAIN_DNS"
echo $MAIN_DNS
}


#Main loop to get IP addresses.
for DOMAIN in ${DOMAIN_LIST}
	do
		DIG_IP_LIST_CURRENT=""
		DIG_IP_LIST=""
		MAIN_DNS="$(get_main_dns "${DOMAIN}") ${DNS_RECURSORS_LIST}"
		for i in ${MAIN_DNS}
			do
				if [[ "${DIG_IP_LIST}" == "" ]];then
					DIG_IP_LIST=$(dig_checker "$(dig $DOMAIN @$i)" | grep -Eo ' [0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}\.[0-9]{,3} ' | sort -n)
				else
					DIG_IP_LIST_CURRENT=$(dig_checker "$(dig $DOMAIN @$i)" | grep -Eo ' [0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}\.[0-9]{,3} ' | sort -n)
					if [[ "$DIG_IP_LIST_CURRENT" == "$DIG_IP_LIST" ]];then
						DIG_IP_LIST=${DIG_IP_LIST_CURRENT}
					else
						log "[ERROR] IP List from "${DOMAIN}" resolved by $i not equal previous"
						exit_script
					fi
				fi
			done
		echo "${DIG_IP_LIST_CURRENT}" > ${NEW_IP_LIST_DIR}/${DOMAIN}

done

exit_script
