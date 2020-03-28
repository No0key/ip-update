#/bin/bash

DNS_RECURSORS_LIST="8.8.8.8 208.67.222.222"
WORKDIR="/home/user/workdir"
LOGFILE="${WORKDIR}/log"
DIG_OUTPUT_FILE="${WORKDIR}/output"
DOMAIN_LIST="habr.com"
IP_LIST_CURRENT=""
IP_LIST=""

[ ! -d ${WORKDIR} ] && mkdir -p ${WORKDIR}
[ ! -f ${LOGFILE} ] && touch ${LOGFILE}
[ ! -f ${DIG_OUTPUT_FILE} ] && touch ${DIG_OUTPUT_FILE}

#Function for logging
log () {
	echo -e "$(date +%d/%m/%Y:%H:%M:%S) $@" >> $LOGFILE
}

log "Script started"

#Function for checking dig return code and dig status
dig_checker () {
DIG_RETURN_CODE=$?
DIG_OUTPUT=$1
DIG_STATUS=$(echo "${DIG_OUTPUT}" | grep -Eo 'status: [A-Z]+?')
if [[ "${DIG_RETURN_CODE}" -ne 0 || "${DIG_STATUS}" != "status: NOERROR" ]]; then
	log "[ERROR] Dig finished with code ${DIG_RETURN_CODE} and ${DIG_STATUS}"
	DIG_CHECK_STATUS="false"
	echo $DIG_CHECK_STATUS
	exit 1
elif [[ $(echo "${DIG_OUTPUT}" | awk '(/^[^;;]/) {print $NF}' | wc -l) -eq 0 ]]; then
	log "[ERROR] Dig finished with code "${DIG_RETURN_CODE}" and "${DIG_STATUS}", received empty list of NS servers"
	DIG_CHECK_STATUS="false"
	echo $DIG_CHECK_STATUS
	exit 1
else
	echo ${DIG_OUTPUT}
fi
}


#Function for getting authoritaive DNS servers for 2nd level domain.
get_main_dns () {
ZONE=$(echo $1 | grep -Eo '[A-Za-z0-9]+?\.[A-Za-z0-9]+?$')
DIG_CHECK_STATUS=$(dig_checker "$(dig ${ZONE} ns)")
if (( $(echo ${DIG_CHECK_STATUS} | wc -c) == 5 )); then
	echo "+++++++++++++++++++++++FALSE+++++++++++++++++++++++"
	exit 1
else
	MAIN_DNS=$(echo "${DIG_CHECK_STATUS}" | grep -Eo ' [A-Za-z0-9]+?\.[A-Z0-9a-z]+?\.[A-Za-z0-9]+?\. ' | shuf -n2 | sort)
	log "Founded authoritative NS servers for ${ZONE} \n$MAIN_DNS"
	echo $MAIN_DNS
fi
}


#Main loop to get IP addresses
for DOMAIN in ${DOMAIN_LIST}
	do
		MAIN_DNS=$(get_main_dns "${DOMAIN}")
		for i in ${MAIN_DNS[@]}
			do
				if [[ "${IP_LIST}" == "" ]];then
					IP_LIST=$(dig_checker "$(dig $DOMAIN @$i)" | grep -Eo ' [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} ' | sort -n)
				else
					IP_LIST_CURRENT=$(dig_checker "$(dig $DOMAIN @$i)" | grep -Eo ' [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} ' | sort -n)
					if [[ "$IP_LIST_CURRENT" == "$IP_LIST" ]];then
						echo "CURRENT IP LIST EQUALS PREVIOUS"
						IP_LIST=${IP_LIST_CURRENT}
					else
						echo "[ERROR]CURRENT AND PREVIOUS IP LISTS NOT EQUAL "
					fi
				fi
			done
done
