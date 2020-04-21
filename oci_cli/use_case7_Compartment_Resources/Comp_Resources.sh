# Version: 1.0
# Usage: ./script.sh <Compartment_Name>
#!/bin/bash


my_dir=$(pwd)
TEMP=$my_dir/temp
LIST_USAGE=$my_dir/Usage.$(date +%F_%R)

>${LIST_USAGE}

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

PREV_REGION=`cat /$USER/.oci/config |grep region|awk -F'=' '{print $2}'`


for i in `oci iam region-subscription list --all|jq -r '.data[]."region-name"'`
do
	OLD=`cat /$USER/.oci/config |grep region|awk -F'=' '{print $2}'`
	sed -i s/$OLD/$i/g /$USER/.oci/config


	green_color "++++++++++++++++++++++++++++++++++++++++++++++++"
	green_color "      SHOWING ALL RESOURCES UNDER $i"
	green_color "++++++++++++++++++++++++++++++++++++++++++++++++"

	echo -e "\nSHOWING ALL RESOURCES UNDER $i" >> ${LIST_USAGE}
	echo -e "+++++++++++++++++++++++++++++++++++++++\n" >> ${LIST_USAGE}

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


#oci search resource structured-search --query-text "query all resources where compartmentId = \'\'\$COMP_OCID\'\'\"
	VAL=`oci search resource structured-search --query-text "query all resources where compartmentId = '$COMP_OCID'"|jq '.data[]'`
	if [ "$VAL" == "[]" ];then
        	red_color "DID NOT FOUND ANY USAGE FOR $1"
	#exit;
	fi

	for comp in `oci search resource structured-search --query-text "query all resources where compartmentId = '$COMP_OCID'"|jq -C -r '.data.items[]."resource-type"' |sort|uniq` 
	do 
		green_color "++++++++++++++   SHOWING ALL LIST OF $comp   +++++++++++++++"
		oci search resource structured-search --query-text "query all resources where compartmentId = '$COMP_OCID'"|jq -C -r '.data.items[].identifier'|sed 's/ /\n/g'|grep -i -w  "ocid1.$comp" | tee -a ${TEMP}
		echo -e "\n"
              	echo -e "| $comp COUNT: `cat ${TEMP}|grep -i -w $comp|uniq|wc -l` " | tee -a ${LIST_USAGE}
		
        done
	> ${TEMP}
sed -i s/$i/$PREV_REGION/g /$USER/.oci/config
	
done
green_color " PLEASE REVIEW THE FILE - ${LIST_USAGE} FOR CHECKING TOTAL USAGE."

rm -f ${TEMP}
