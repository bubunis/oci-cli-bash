# Version: 1.0
# Usage:
#!/bin/bash
# Written by - MONOJIT ROY

function red_color() {
    COLOR='\033[01;31m' # bold red
    RESET='\033[00;00m' # normal white
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${COLOR}${MESSAGE}${RESET}"
}
function green_color() {
    GREEN='\e[32m' # bold green
    RESET='\033[00;00m' # normal white
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${GREEN}${MESSAGE}${RESET}"
}

ALL_NAME_C=`oci iam compartment list --all |jq -r '.data[].name'`
ALL_OCID_C=`oci iam compartment list --all |jq -r '.data[].id'`
ALL_NAME_U=`oci iam user list --all|jq -r '.data[].name'`
if [ ! -z $2 ];then
COMP_OCID_ARG=`oci iam compartment list --all|grep -w -B4 $2|grep "ocid1.compartment"|awk -F':' '{print $2}'|tr -d '", '`
fi

if [ $# -eq 0 ];then

red_color "Usage: ./script < Compartment_NAME OR Compartment_OCID > e.g. ./script monroy OR ./script ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6xx"
red_color "Usage: ./script < Compartment_NAME OR Compartment_OCID > -v e.g. ./script monroy -v OR ./script ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6xx -v"
green_color "'-v' is to display FJSONs that are being executed to collate the date"
exit 0;
fi

#### CHECKING IDCS / SSO Users ####



if [ "`echo -e $ALL_NAME_U|grep -o $1|uniq`" == $1 ];then
	USER_OCID=`oci iam user list --all|jq -r '.data[]'|tr -d '"'|grep -w -B5 -i "name: $1,"|grep ocid1.user|awk -F':' '{print $2}'|tr -d ', '`
fi

if [ -z $USER_OCID ];then
	green_color "SEARCHING POSSIBLE MATCHES.."
	oci iam user list --all|jq -r '.data[]'|tr -d '"'|grep $1|grep name
	if [ $? -eq 1 ];then
		red_color "$1: NOT FOUND"
		exit;
	fi
#else
#	green_color  "$1 FOUND, SEARCHING POLICIES.."
exit;
fi

green_color  "USER: $1 FOUND, SEARCHING POLICIES.."

#if [ "`echo -e $ALL_NAME_C|grep -o $1|uniq`" == $1 ];then
#        COMP_OCID=`oci iam compartment list --all|grep -w -B4 $1|grep "ocid1.compartment"|awk -F':' '{print $2}'|tr -d '", '`
#elif [ "`echo -e $ALL_OCID_C|grep -o $1|uniq`" == $1 ];then
#        COMP_OCID=$1
#else
#        red_color "$1 DOESN'T MATCH WITH ANY COMPARTMENT"
#        exit 0;
#fi

if [ -z /$USER/.oci/config ];then
        red_color "SEEMS CONFIG FILE NOT PRESENT. PLEASE RUN -"
        green_color "oci setup config -- To SETUP THE CONFIG FILE"
        green_color "oci setup repair-file-permissions --file /$USER/.oci/config -- TO REPAIR THE SAME AFTER CONFIGURATION"
        exit 0;
fi

##### IDENTIFYING GROUP OCID ######
GRP_OCID=`oci iam user list-groups --user-id $USER_OCID --all| jq -r '.data[].id'`
GRP_NAME=(`oci iam user list-groups --user-id $USER_OCID --all| jq -r '.data[].name'|sed 's/\n/ /g'`)
green_color "USER: $1 HAS ASSOCIATION WITH - ${#GRP_NAME[*]} GROUP(s)"
printf '%s\n' "${GRP_NAME[@]}"

if [ ${#GRP_NAME[@]} -eq 0 ];then
	red_color "QUTTING..."
	exit 0;
fi
green_color "SHOWING POLICY STATEMENTS RELATED TO GROUP.."
for COMP_OCID in `oci iam compartment list --all |jq -r '.data[].id'`
do
	for item in "${GRP_NAME[@]}"
	do
		#green_color "FOR $item GROUP:-"
		oci iam policy list -c $COMP_OCID --all|jq '.data[].statements'|grep $item
#		if [ $? -gt 0 ];then
#			red_color "NO POLICY FOUND"
#		fi
	done
done

if [ ! -z $COMP_OCID_ARG ];then
	green_color "SHOWING ALL POLICIES BEING SET UNDER COMPARTMENT: $2"
	oci iam policy list -c $COMP_OCID_ARG --all|jq -r '.data[].statements[]'
	ALL_POLICY_LIST=`oci iam policy list -c $COMP_OCID_ARG --all|jq -r '.data[].statements[]'`
	for item in "${GRP_NAME[@]}"
	do
		echo $ALL_POLICY_LIST|grep -o $item 1>/dev/null
		if [ $? -gt 0 ];then
			red_color "THE GROUP $item SEEMS NOT PRESENT IN ANY POLICY FOR COMPARTMENT: $2"
		else
			green_color "THE GROUP $item SEEMS PRESENT IN THE POLICY FOR COMPARTMENT: $2"
		fi		
	done
	if [ $? -gt 0 ];then
		red_color "FOUND NONE"
	fi
fi 
