#!/bin/ksh
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

PROGRAM=$0
PROGRAM_NAME=$(basename $0)
PROGRAM_DIR=$(which $0)
PROGRAM_DIR=${PROGRAM_DIR%/*}
PROGRAM_DIR=$(cd ${PROGRAM_DIR};pwd)
PROGRAM_VAH=$(echo ${PROGRAM_DIR}|awk -F/ '{print $2}')
PROGRAM_PARAMETERS=$*
PROGRAM_VERSION="0.99"
LOG_DIR="/var/log/update_haproxy/"
LOG_FILE="${LOG_DIR}update_haproxy.log"
REGISTRY_FILE="/etc/update_haproxy/registry.cfg"
TEMPLATE_FILE="/etc/update_haproxy/template.cfg"
AWS_BINARY="/usr/bin/aws"
AWS_OUTPUT_TYPE="text"
AWS_REGION_CODE="us-east-1"

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
    Print_Info "####  Monitor Aurora Cluster and change HA-Proxy as required ###"
    Print_Info "################################################################"
    Print_Info "Program Info"
    Print_Info " Name			: ${PROGRAM_NAME}"
    Print_Info " Dir			: ${PROGRAM_DIR}"
    Print_Info " Version		: ${PROGRAM_VERSION}"
    Print_Info " Parameters		: ${PROGRAM_PARAMETERS}"
    Print_Info " Registry File  	: ${REGISTRY_FILE}"
    Print_Info " Parameters passed	: ${NUM_PARAMETERS}"
  
    if [[ -a "${PROGRAM_REGISTRY}" ]]
    then
        grep -v "^#" ${PARAM_FILE} 2>/dev/null|while read LINE
        do
            Print_Info "    ${LINE}"
        done
    fi

    Print_Info
    Print_Info "  Log File		: ${LOG_FILE}"
}

Initialization()
{
   USER=$(whoami)
# removing / negating if clause for testing
#   if [[ "${USER}" != "haproxy" ]]
   if [[ "${USER}" = "haproxy" ]]
   then
	Print_Error "Must be run\\logged in as \"haproxy\"."
	exit 1
   fi

   while getopts a:m:p:H:lh OPT
   do
	case $OPT in
		a)  CLUSTER_NAME=$OPTARG ;;
                m)  RUN_MONITOR_MODE=TRUE ;;
		p)  PROXY_PORT=$OPTARG ;;
                H)  HEALTH_CHECK_PORT=$OPTARG ;;
		l)  list_registry_contents 
		    exit 0 ;;
		r)  CLUSTER_TO_REMOVE=$OPTARG ;;

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
     echo "Usage: ${PROGRAM_NAME} <-a Aurora Cluster Name>  <-c Aurora cluster Name >"
     echo "       and other options"
}
##############################################################################
# Procedure	: find_cluster_members
# Purpose 	: Find all DB instances of a given Cluster
###############################################################################
find_cluster_information()
{
   
   CLUSTER_MEMBERS=$(${AWS_BINARY} rds describe-db-clusters --db-cluster-identifier ${CLUSTER_NAME} --region ${AWS_REGION_CODE} \
                      --output ${AWS_OUTPUT_TYPE}   --query 'DBClusters[].DBClusterMembers[].DBInstanceIdentifier[]')

   ENGINE_TYPE=$(${AWS_BINARY} rds describe-db-clusters --db-cluster-identifier ${CLUSTER_NAME} --region ${AWS_REGION_CODE} \
                      --output ${AWS_OUTPUT_TYPE}   --query 'DBClusters[].Engine[]')

   ENGINE_VERSION=$(${AWS_BINARY} rds describe-db-clusters --db-cluster-identifier ${CLUSTER_NAME} --region ${AWS_REGION_CODE} \
                      --output ${AWS_OUTPUT_TYPE}   --query 'DBClusters[].EngineVersion[]')

   CLUSTER_NODE_COUNT=$( echo ${CLUSTER_MEMBERS} | wc -w)
  
   Print_Info ""
   Print_Info "  Cluster name     : ${CLUSTER_NAME}"
   Print_Info "  Nodes found      : ${CLUSTER_NODE_COUNT}"
   Print_Info "  Cluster members  : ${CLUSTER_MEMBERS}"
   Print_Info "  Engine           : ${ENGINE_TYPE}"
   Print_Info "  Engine version   : ${ENGINE_VERSION}"
   Print_Info ""
}

##############################################################################
# Procedure : add_to_registry
# Purpose   : Adding all entries to Registry file 
#################################################################
add_to_registry()
{
      
      CONFIG_PRESENT=$(grep -q $CLUSTER_NAME $REGISTRY_FILE && echo $? ) 
      if [[ $CONFIG_PRESENT -eq 0 ]]
      then 
          Print_Error "   Instance already Present in Registry File, skipping"
          Print_Error "   Exiting"
          exit 1
      elif [[ "${ENGINE_TYPE}" != 'aurora-postgresl' || "${ENGINE_TYPE}" != 'aurora'  ]]
      then 
          Print_Error "   Instance provided is not an Aurora type , skipping"
          Print_Error "   Exiting"
          exit 1
      elif [[ "${CLUSTER_MEMBERS}" -le 2 ]]
      then 
          Print_Error "   Cluster does not have any read replicas "
          Print_Error "   Exiting"
          exit 1 
      elif  [[ "$(grep -q ${PROXY_PORT} ${REGISTRY_FILE} ; echo $? )"  -eq 0 ]]; 
      then 
          Print_Error "   Proxy Port in use , Please check and try again"
          Print_Error "   Exiting"
          exit 1 
      elif  [[ "$( grep -q ${HEALTH_CHECK_PORT} ${REGISTRY_FILE} ; echo $? )" -eq 0  ]]
      then
          Print_Error "   Health Check Port in Use. Please check and try again "
          Print_Error "   Exiting"
          exit 1 
      else
          Print_Info "   Adding Entry to Registry File "
          echo "${CLUSTER_NAME};${ENGINE_TYPE};${ENGINE_VERSION};${PROXY_PORT};${HEALTH_CHECK_PORT}" >> ${REGISTRY_FILE}
      fi
}
##############################################################################
# Procedure : generate_configuration
# Purpose   : Generate HA Prroxy Configuration for server 
##############################################################################
generate_configurartion()
{
    cp ${TEMPLATE_FILE} /tmp/${CLUSTER_NAME}.cfg.latest

    echo "/tmp/${CLUSTER_NAME}.cfg.latest"

sleep 10

    sed "s/_clustername_/${CLUSTER_NAME}/g; \
         s/_proxy_port_number/${PROXY_PORT}/g; \
         s/_healtcheckport_/${HEALTH_CHECK_PORT}/g;" "/tmp/${ClUSTER_NAME}.cfg.latest"

       for node in  ${CLUSTER_MEMBERS[@]};
          do
            MEMBER_ENDPOINT=$(${AWS_BINARY} rds describe-db-instances --db-instance-identifier ${node} \
                               --output text --query 'DBInstances[].Endpoint[].Address[]' --region ${AWS_REGION_CODE})

            MEMBER_PORT=$(${AWS_BINARY} rds describe-db-instances --db-instance-identifier ${node} \
                          --output text --query 'DBInstances[].Endpoint[].Port[]' --region ${AWS_REGION_CODE})

            echo "server $node ${MEMBER_ENDPOINT}:${MEMBER_PORT} check port ${HEALTH_CHECK_PORT}" \
                 >> "/tmp/${ClUSTER_NAME}.cfg.latest"
          done
}

##############################################################################
# Procedure : list_registry_contents
# Purpose   : List Databases on the Registry
##############################################################################
list_registry_contents()
{
    if [[ -a "${REGISTRY_FILE}" ]]
    then
        egrep -v "^#" ${REGISTRY_FILE}|while read LINE
        do
            CLUSTER_NAME=$(echo ${LINE}|awk -F ';' '{print $1}')
            =$(echo ${LINE}|awk -F':|=' '{print $2}')
            if [[ "${PARAM_KEY}" != "" ]]
            then
                eval ${PARAM_KEY}=\${${PARAM_KEY}:-${PARAM_VALUE}}
            fi
        done
    fi   
}
##############################################################################
# Main Routine
##############################################################################
NUM_PARAMETERS="$#" 
Initialization $*
find_cluster_information
add_to_registry
generate_configuration
