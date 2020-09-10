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

