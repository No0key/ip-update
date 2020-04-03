#/bin/bash

DNS_RECURSORS_LIST="8.8.8.8 208.67.222.222"
WORKDIR="/home/user/workdir"
LOGFILE="${WORKDIR}/log"
NEW_IP_LIST="${WORKDIR}/iplist"
DIG_OUTPUT_FILE="${WORKDIR}/output"
DOMAIN_LIST="whitelist.yclients.cloud office.yclients.tech vpn.yclients.cloud"
IP_LIST_CURRENT=""
IP_LIST=""

[ ! -d ${WORKDIR} ] && mkdir -p ${WORKDIR}
[ ! -f ${LOGFILE} ] && touch ${LOGFILE}
[ ! -f ${DIG_OUTPUT_FILE} ] && touch ${DIG_OUTPUT_FILE}
[ ! -f ${NEW_IP_LIST} ] && touch ${NEW_IP_LIST}
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
RESOLVER=$(echo "${DIG_OUTPUT}" | grep -Eo ' [A-Za-z0-9]+?\.[A-Z0-9a-z]+?\.[A-Za-z0-9]+?\. ')
if [[ $(echo "${DIG_OUTPUT}" | awk '(/^[^;;]/) {print $NF}' | wc -l) -eq 0 ]]; then
	log "[ERROR] Dig finished with code "${DIG_RETURN_CODE}" and "${DIG_STATUS}", received empty list of DNS records"
	echo "false"
	kill -9 $$
elif [[ "${DIG_RETURN_CODE}" -ne 0 || "${DIG_STATUS}" != "status: NOERROR" ]]; then
	log "[ERROR] Dig finished with code ${DIG_RETURN_CODE} and ${DIG_STATUS} resolved by ${RESOLVER}"
	echo "false"
	kill -9 $$
else
	echo ${DIG_OUTPUT}
fi
}


#Function for getting authoritaive DNS servers for 2nd level domain.
get_main_dns () {
DOMAIN=$1
ZONE=$(echo $1 | grep -Eo '[A-Za-z0-9]+?\.[A-Za-z]+?$')
DIG_CHECK_STATUS=$(dig_checker "$(dig ${ZONE} ns)")
if [[ "${DIG_CHECK_STATUS}" == "false" ]]; then
	exit 1
else
	MAIN_DNS=$(echo "${DIG_CHECK_STATUS}" | grep -Eo ' [A-Za-z0-9]+?\.[A-Z0-9a-z]+?\.[A-Za-z0-9]+?\. ' | shuf -n2 | sort)
	log "Founded authoritative NS servers for ${DOMAIN} \n$MAIN_DNS"
	echo $MAIN_DNS
fi
}


#Main loop to get IP addresses
for DOMAIN in ${DOMAIN_LIST}
	do
		DIG_IP_LIST_CURRENT=""
		DIG_IP_LIST=""
		MAIN_DNS="$(get_main_dns "${DOMAIN}") ${DNS_RECURSORS_LIST}"
		for i in ${MAIN_DNS}
			do
				if [[ "${DIG_IP_LIST}" == "" ]];then
					DIG_IP_LIST=$(dig_checker "$(dig $DOMAIN @$i)" | grep -Eo ' [0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}\.[0-9]{,3} ' | sort -n)
					echo "FIRST IP LIST RESOLVED by $i"
				else
					DIG_IP_LIST_CURRENT=$(dig_checker "$(dig $DOMAIN @$i)" | grep -Eo ' [0-9]{,3}\.[0-9]{,3}\.[0-9]{,3}\.[0-9]{,3} ' | sort -n)
					if [[ "$DIG_IP_LIST_CURRENT" == "$DIG_IP_LIST" ]];then
						echo "CURRENT IP LIST resolved by $i EQUALS PREVIOUS "
						DIG_IP_LIST=${DIG_IP_LIST_CURRENT}
					else
						log "[ERROR] IP List from "${DOMAIN}" resolved by $i not equal previous"
						exit 1
						kill -9 $$
					fi
				fi
				echo $DIG_IP_LIST_CURRENT > "${NEW_IP_LIST}_$DOMAIN"
			done
done
