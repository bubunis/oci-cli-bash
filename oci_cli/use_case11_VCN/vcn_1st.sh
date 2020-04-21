# Version: 1.1
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

#my_dir=$(pwd)
#BS_OPT=$my_dir/output.txt
#TEMP=$my_dir/temp1
#TEMP1=$my_dir/temp2
#>$TEMP
#>$TEMP1
#>$BS_OPT

ALL_NAME_C=`oci iam compartment list --all |jq -r '.data[].name'`
ALL_OCID_C=`oci iam compartment list --all |jq -r '.data[].id'`



####
# COPYING config FILE SAFELY
####

cp /$USER/.oci/config /$USER/.oci/config.BKP.$(date +"%m_%d_%Y")


####
# VALIDATING THE REGION
####
echo -e "DEFAULT REGION MENTIONED IN CONFIG FILE - `cat /$USER/.oci/config |grep -A5 DEFAULT|grep region|awk -F'=' '{print $2}'`"
read -p "DO YOU WANT TO CHANGE IT? [ Y/N ]: " RESP
if [ $RESP == "Y" ] || [ $RESP == "y" ];then
        OLD=`cat /$USER/.oci/config |grep -A5 DEFAULT| grep region|awk -F'=' '{print $2}'`
        echo -e "\n-----------------------"
        oci iam region-subscription list --all|jq -r '.data[]."region-name"'
        echo -e "------------------------\n"

        read -p "SELECT THE REGION WHICH YOU WISH TO CHOOSE: " region
        sed -i s/$OLD/$region/g /$USER/.oci/config
fi




####
# VALIDATING THE COMPARTMENT
####
read -p "INSERT COMPARTMENT NAME or OCID: " COMP
if [ "`echo -e $ALL_NAME_C|grep -o $COMP|uniq`" == $COMP ];then
        COMP_OCID=`oci iam compartment list --all|grep -w -B4 $COMP|grep "ocid1.compartment"|awk -F':' '{print $2}'|tr -d '", '`

elif [ "`echo -e $ALL_OCID_C|grep -o $COMP|uniq`" == $COMP ];then
        COMP_OCID=$COMP
else
        red_color "$COMP DOESN'T MATCH WITH ANY COMPARTMENT"
        exit 0;
fi

####
# VALIDATING THE PRESENSE OF CONFIG FILE
####
if [ -z /$USER/.oci/config ];then
        red_color "SEEMS CONFIG FILE NOT PRESENT. PLEASE RUN -"
        green_color "oci setup config -- To SETUP THE CONFIG FILE"
        green_color "oci setup repair-file-permissions --file /$USER/.oci/config -- TO REPAIR THE SAME AFTER CONFIGURATION"
        exit 0;
fi


####
# VALIDATING THE PRESENSE OF CONFIG FILE
####
if [ -z /$USER/.oci/config ];then
        red_color "SEEMS CONFIG FILE NOT PRESENT. PLEASE RUN -"
        green_color "oci setup config -- To SETUP THE CONFIG FILE"
        green_color "oci setup repair-file-permissions --file /$USER/.oci/config -- TO REPAIR THE SAME AFTER CONFIGURATION"
        exit 0;
fi


COUNT=`oci network vcn list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a |jq '.data[]| .displayName + " " + .id'|column -t|wc -l`

if [ $COUNT -eq 0 ];then
	red_color "NO VCN PRESENT, Quitting.."
	exit
else
	echo -e "\n"
	green_color "FOUND BELOW VCNs:"
	green_color "-----------------"
	oci network vcn list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a |jq '.data[]| ."display-name" + " " + .id'|column -t
fi

echo -e "\n"
read -p "Enter the OCID of the VCN which you want to check: " VCN_OCID

#oci network subnet list -c $COMP_OCID --vcn-id $VCN_OCID
echo -e "\n"
for ROUTE_ID in `oci network route-table list -c $COMP_OCID --vcn-id $VCN_OCID |jq -r -C '.data[].id'`
do
	echo -e "ROUTE-NAME: `oci network route-table get --rt-id $ROUTE_ID|jq -r -C '.data."display-name"'`"
	VAL=`oci network route-table get --rt-id $ROUTE_ID|jq -r -C '.data."route-rules"[]'`
	if [ "$VAL" == "" ];then
		red_color "ROUTE-RULES NOT FOUND"
	else
		green_color "ROUTE-RULES FOUND"
		oci network route-table get --rt-id $ROUTE_ID|jq -r -C '.data."route-rules"[]'
	fi
done	

green_color "PLEASE VERIFY WHETHER THE DESTINATION IP ADDRESS IS A PART OF ABOVE CIDRs"
echo -e "\nLIST OF MAPPED SECLIST-SUBNET IN THIS VCN:"
echo -e "------------------------------------------\n"
 oci network subnet list -c $COMP_OCID --vcn-id $VCN_OCID | jq -r -C '.data[]| "\("IP-RANGE:\t\t") \(."cidr-block") \("\nSEC-LIST-OCID:\t\t")\(."security-list-ids"[]) \("\nSUBNET-OCID:\t\t") \(.id) \("\nSUBNET-NAME:\t\t") \(."display-name") \("\n")"'

read -p  "PLEASE CHOOSE THE SECLIST OCID THAT MATCHES WITH THE CIDR RANGE AND THE SERVER IP:" OCID_SEC
read -p  "INSERT THE PORT NUMBER YOU ALLOWED IN THE INGRESS PART OF SECURITY-LIST $OCID_SEC:" PORT

oci network security-list get  --security-list-id $OCID_SEC |jq -r -C '.data."ingress-security-rules"[]."tcp-options"."destination-port-range"|"\(.max) \(.min)"'|grep -v null|grep $PORT 1>/dev/null
	VAL=`echo $?`
	if [ $VAL -eq 1 ];then
		red_color "ENTERED PORT: $PORT IS NOT PART OF THE INGRESS RULE OF:${OCID_SEC}"
	else
		green_color "ENTERED PORT: $PORT IS PART OF THE INGRESS RULE OF:${OCID_SEC}"

	fi

mv /$USER/.oci/config.BKP.$(date +"%m_%d_%Y") /$USER/.oci/config
