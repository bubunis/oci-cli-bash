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

OCID_I=`curl -sfm 3 http://169.254.169.254/opc/v1/instance/ | jq -r '.id'`
echo -e "FOUND \e[1m$OCID_I\e[0m AS INSTANCE OCID"
for i in `oci iam compartment list --all |jq -r '.data[].id'`
do
	oci compute instance list -c $i |jq -r -C '.data[].id'|grep $OCID_I 1>/dev/null 2>/dev/null
	if [ $? -eq 0 ];then
		echo -e "FOUND \e[1m$i\e[0m AS THE COMPARTMENT OCID"
		OCID_C=`echo $i` 
		break;
	fi 
done
green_color " EXISTING CONSOLE HISTORY IF ANY: "
oci compute console-history list -c $OCID_C | jq -r '.data[]'

green_color "DELETING.."
for i in `oci compute console-history list -c $OCID_C |jq -r '.data[].id'`
do
	oci compute console-history delete --instance-console-history-id $i --force;
	echo "DONE.."
done

green_color "RETRIEVING CONSOLE HISTORY. PLEASE WAIT.."
oci compute console-history capture --instance-id $OCID_I 1>/dev/null 2>/dev/null
sleep 10;
STATE=`oci compute console-history list -c $OCID_C --instance-id $OCID_I|jq -r -C '.data[]."lifecycle-state"'`
if [ "$STATE" == "SUCCEEDED" ];then
	OCID_CON_H=`oci compute console-history list -c $OCID_C --instance-id $OCID_I|jq -r -C '.data[].id'`
	oci compute console-history get-content --length 10000000 --file - --instance-console-history-id $OCID_CON_H
else
	red_color "$STATE IS NOT YET "SUCCEEDED". QUITTING.."
	exit 0;
fi
echo -e "\n"
green_color "----- END OF CONSOLE OUTPUT -----"
green_color "----- RUNNING SOSREPORT -----"
sosreport


