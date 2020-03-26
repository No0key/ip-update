#/bin/bash

DNS_RECURSORS_LIST="8.8.8.8 208.67.222.222"
WORKDIR="/home/user/workdir"
LOGFILE="${WORKDIR}/log"
DOMAIN_LIST="habr.com"

[ ! -d ${WORKDIR} ] && mkdir -p ${WORKDIR}
[ ! -f ${LOGFILE} ] && touch ${LOGFILE}
[ ! -f ${DIG_OUTPUT} ] && touch ${DIG_OUTPUT}

#Function for logging
log () {
	echo -e "$(date +%d/%m/%Y:%H:%M:%S) $@" >> $LOGFILE
}

log "Script started"

#Function for checking dig return code and dig status

dig_checker () {
DIG_RETURN_CODE=$?
DIG_INPUT=$1
DIG_STATUS=$(echo "${DIG_INPUT}" | grep -Eo 'status: [A-Z]+?')
if [[ "${DIG_RETURN_CODE}" -ne 0 || "${DIG_STATUS}" != "status: NOERROR" ]]; then
                log "Dig finished with code $? and $DIG_STATUS"
		DIG_CHECK_STATUS="false"
		echo $DIG_CHECK_STATUS
                exit 1
elif [[ $(echo "${DIG_INPUT}" | awk '(/^[^;;]/) {print $NF}' | shuf -n2 | sort | wc -l) -eq 0 ]]; then
                log "Dig finished with code $? and "${DIG_STATUS}", received empty list of NS servers"
		DIG_CHECK_STATUS="false"
		echo $DIG_CHECK_STATUS
                exit 1
else
	echo ${DIG_INPUT}
fi
}



#Function for getting authoritaive DNS servers
get_main_dns () {
DOMAIN=$1
DIG_CHECK_STATUS=$(dig_checker "$(dig $DOMAIN ns)")
if (( $(echo ${DIG_CHECK_STATUS} | wc -c) == 5 )); then
	echo "+++++++++++++++++++++++FALSE+++++++++++++++++++++"
	exit 1
else
	MAIN_DNS=$(echo "${DIG_CHECK_STATUS}" | grep -E ' [A-Za-z0-9]+?\.[A-Z0-9a-z]+?\.[A-Za-z0-9]+?\. ')
	log "Founded authoritative NS servers for $DOMAIN \n$MAIN_DNS"
	echo $MAIN_DNS
fi
}




get_main_dns "habr.com"

#for DOMAIN in ${DOMAIN_LIST}
#do
#		get_main_dns "${DOMAIN}"
#done
