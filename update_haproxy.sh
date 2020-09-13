#!/bion/ksh
##############################################################################
##  PROGRAM:	update_haproxy
##
##  AUTHOR:	Gopalakrishnan Subramanian
##
##  SYNOPSIS:	update_haproxy <ClUSTER_NAME> <SECRETS_FRIENDLY_NAME|ARN>
##
##  DESCRIPTION:
##	This script queries and Aurora Cluster and creates an additional configuration
##	file for haproxy on the server .
##
##  MANDATORY PARAMETERS:
##	-c : Aurora cluster Name 
##
##
##  HISTORY:
##  09-SEP-20 SGK
##	v0.99 and intial version
##############################################################################
#
PROGRAM=$0
PROGRAM_NAME=$(basename $0)
PROGRAM_DIR=$(which $0)
PROGRAM_DIR=${PROGRAM_DIR%/*}
PROGRAM_DIR=$(cd ${PROGRAM_DIR};pwd)
PROGRAM_VAH=$(echo ${PROGRAM_DIR}|awk -F/ '{print $2}')
PROGRAM_PARAMETERS=$*
PROGRAM_VERSION="0.99"
LOG_DIR="/var/log/update_haproxy/"
#
##############################################################################
Print_Error ()
{
    [[ ${PRINT_VERBOSE:-Y} = "Y" ]] && echo "$(date +%T): ERROR: $*"
    [[ -d "${LOG_DIR:-/XxXx}" ]] && echo "$(date +%T): ERROR: $*" >> ${LOG_FILE}
}

Print_Info ()
{
    [[ ${PRINT_VERBOSE:-Y} = "Y" ]] && echo "$(date +%T): INFO : $*"
    [[ -d "${LOG_DIR:-/XxXx}" ]] && echo "$(date +%T): INFO : $*" >> ${LOG_FILE}
}

Print_Warn ()
{
    [[ ${PRINT_VERBOSE:-Y} = "Y" ]] && echo "$(date +%T): WARN : $*"
    [[ -d "${LOG_DIR:-/XxXx}" ]] && echo "$(date +%T): WARN : $*" >> ${LOG_FILE}
}

Print_File ()
{
    if [[ -a "${1}" ]]
    then
        [[ ${PRINT_VERBOSE:-Y} = "Y" ]] && cat ${1}
        [[ -d "${LOG_DIR:-/XxXx}" ]] && cat ${1} >> ${LOG_FILE}
    fi
}


Print_Program_Info ()
{
    Print_Info "################################################################"
    Print_Info "####  Monitor Aurora Clustner and Change Proxy as Required  ####"
    Print_Info "################################################################"
    Print_Info "Program Info"
    Print_Info " Name		: ${PROGRAM_NAME}"
    Print_Info " Dir		: ${PROGRAM_DIR}"
    Print_Info " Version	: ${PROGRAM_VERSION}"
    Print_Info " Parameters	: ${PROGRAM_PARAMETERS}"
    Print_Info " Registry File  : ${PROGRAM_REGISTRY}"
  
    if [[ -a "${PROGRAM_REGISTRY}" ]]
    then
        grep -v "^#" ${PARAM_FILE} 2>/dev/null|while read LINE
        do
            Print_Info "    ${LINE}"
        done
    fi

    Print_Info
    Print_Info "  Log File              : ${LOG_FILE}"
}

Initialization()
{
   USER=$(whoami)

   if [[ "${USER}" != "haproxy" ]]
   then
	Print_Error "Must be run\\logged in as \"haproxy\"."
	exit 1
   fi

   while getopts a:c:l:r:sh OPT
   do
	case $OPT in
		a)  CLUSTER_NAME=$OPTARG ;;
		c)  show_current_config
		    exit 0 ;;
		l)  list_registry_contents 
		    exit 0 ;;
		r)  CLUSTER_TO_REMOVE=$OPTARG ;;
		s)  show_proxy_configuration
		    exit 0 ;;
		h)  Usage
		    exit 0 ;;
		\?) Usage
		    exit 1 ;;
	esac
done

CFG_DIR=${CFG_DIR:-/etc/monitor_proxy}
LOG_DIR=${LOG_DIR:-/var/log/update_haproxy}

Print_Program_Info

}
##############################################################################
# Procedure	: Usage
# Purpose 	: Display the usage of this script
###############################################################################
Usage()
{
     echo "Usage: ${PROGRAM_NAME} <-a Aurora Cluster Name>  <-c Aurora cluster Name > [


