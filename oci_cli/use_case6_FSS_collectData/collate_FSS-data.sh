# Version: 1.0
# Usage:
#!/bin/bash

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

if [ $# -eq 0 ];then

red_color "Usage: ./script < Compartment_NAME OR Compartment_OCID > e.g. ./script monroy OR ./script ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6xx"
red_color "Usage: ./script < Compartment_NAME OR Compartment_OCID > -v e.g. ./script monroy -v OR ./script ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6xx -v"
green_color "'-v' is to display FJSONs that are being executed to collate the date"
exit 0;
fi

if [ "`echo -e $ALL_NAME_C|grep -o $1|uniq`" == $1 ];then
	COMP_OCID=`oci iam compartment list --all|grep -w -B4 $1|grep "ocid1.compartment"|awk -F':' '{print $2}'|tr -d '", '`
	
elif [ "`echo -e $ALL_OCID_C|grep -o $1|uniq`" == $1 ];then
	COMP_OCID=$1
else
	red_color "$1 DOESN'T MATCH WITH ANY COMPARTMENT"
	exit 0;
fi

if [ -z /$USER/.oci/config ];then
	red_color "SEEMS CONFIG FILE NOT PRESENT. PLEASE RUN -"
        green_color "oci setup config -- To SETUP THE CONFIG FILE"
        green_color "oci setup repair-file-permissions --file /$USER/.oci/config -- TO REPAIR THE SAME AFTER CONFIGURATION"
        exit 0;
fi


for i in `oci iam availability-domain list |jq -r '.data[].name'`
do

	green_color "SHOWING FSS IN $i"
	green_color "+++++++++++++++++"
	VAL=`oci fs mount-target list -c $COMP_OCID --availability-domain $i|wc -c`
	if [ $VAL -eq 0 ];then
		red_color "FSS NOT FOUND"
	else
		if [ -z "$2" ];then
			echo "MOUNT-TARGET-OCID : `oci fs mount-target list -c $COMP_OCID --availability-domain $i| jq -r '.data[].id'`"|column -t
			echo "FILESYSTEM-OCID : `oci fs file-system list -c $COMP_OCID --availability-domain $i| jq -r '.data[].id'`"|column -t
			#oci fs export-set list -c $COMP_OCID --availability-domain $i
			OCID_PrivIP=`oci fs mount-target list -c $COMP_OCID --availability-domain $i|jq -r '.data[]."private-ip-ids"[]'`
			echo -e "IP: `oci network private-ip get --private-ip-id $OCID_PrivIP|jq -r '.data."ip-address"'`"
			OCID_VCN=`oci fs export-set list -c $COMP_OCID --availability-domain $i |jq -r '.data[]."vcn-id"'`
			green_color "SHOWING RELATED SECURITY LIST IN $i"
			green_color "++++++++++++++++++++++++++++++++++++++++++++++++++"
			echo -e "\nEGRESS --"
			oci network security-list list -c $COMP_OCID --vcn-id $OCID_VCN |jq '.data[]."egress-security-rules"[]."tcp-options"."destination-port-range"'|grep -v null|jq '.|select(.max==2050 or .max==111 or .max==2048)'

			echo -e "\nINGRESS --"
			oci network security-list list -c $COMP_OCID --vcn-id $OCID_VCN |jq '.data[]."ingress-security-rules"[]."tcp-options"."destination-port-range"'|grep -v null|jq '.|select(.max==2050 or .max==111 or .max==2048 or .max==2049)'

		elif [ $2 == "-v" ];then
			oci fs file-system list -c $COMP_OCID --availability-domain $i
			oci fs mount-target list -c $COMP_OCID --availability-domain $i	
	fi
fi
done
