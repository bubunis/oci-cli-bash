#!/bin/bash
#
# Requirements
# - jq package (usually installable via `$sudo yum install jq -y`)
# - Bash shell
# - OCI CLI installed and configured
#   https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm
#
# (this script won't capture LBs inside the root compartment)
#
# Known limitations
# - It doesn't list LBs inside root compartment
# - It lists objects under first level compartments only. Not recursive.
#
 

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


 
command -v oci >/dev/null 2>&1 || { echo >&2 "OCI CLI is not installed."; exit 1; }
 
printTitle() {
    title=$1; str=-; num="80"
    titlelength=`echo -n $title | wc -c`
    repeat=$(expr $num - $titlelength)
    v=$(printf "%-${repeat}s" "$str")
    printf "$title"
    echo "${v// /$str}"
}


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



 
#for compartmentID in `oci iam compartment list --all | jq -r '.data[] | .id +" "+."lifecycle-state"' | grep "ACTIVE" | awk '{print $1}'`
#do
    #compartmentID=`oci iam compartment get --compartment-id $compartmentID | jq -r '[.data.id]|.[]'`
    #compartmentName=`oci iam compartment get --compartment-id $compartmentID | jq -r '[.data.name]|.[]'`
#    if [ `oci lb load-balancer list -c $COMP_OCID | wc -l` -gt 0 ]
#    then
        #printTitle "COMPARTMENT $compartmentName"
#        echo ">> Policy"
#        oci lb policy list -c $COMP_OCID
#        echo ">> Protocol"
#        oci lb protocol list -c $COMP_OCID
#        echo ">> Shape"
#        oci lb shape list -c $COMP_OCID
#        for lbID in `oci lb load-balancer list -c $COMP_OCID | jq -r '[.data[].id]|.[]'`
#        do
#            loadBalancerDisplayName=`oci lb load-balancer get --load-balancer-id $lbID | jq -r '[.data."display-name"]|.[]'`
#            printTitle "Load Balancer $loadBalancerDisplayName"
#            echo ">> LB Details"
#            oci lb load-balancer get --load-balancer-id $lbID
#            echo ">> Hostname"
#            oci lb hostname list --load-balancer-id $lbID
#            echo ">> LB health"
#            oci lb load-balancer-health get --load-balancer-id $lbID
#            echo ">> Certs"
#            oci lb certificate list --load-balancer-id $lbID
#            if [ `oci lb backend-set list --load-balancer-id $lbID | wc -l` -gt 3 ]
#            then
#                for backend in `oci lb backend-set list --load-balancer-id $lbID | jq -r '[.data[].name]|.[]'`
#                do
#                    echo ">> Backend set"
#                    oci lb backend-set get --load-balancer-id $lbID --backend-set-name $backend
#                    echo ">> Backend set health"
#                    oci lb backend-set-health get --load-balancer-id $lbID --backend-set-name $backend
#                    echo ">> Backend set health check"              
#                    oci lb health-checker get --load-balancer-id $lbID --backend-set-name $backend
#                done
#            fi
#        done
#    else
#        echo "No Load Balancers in compartment $COMP"
#    fi
#done

green_color "FOUND BELOW LOAD-BALANCERS IN THE COMPARTMENT"
green_color "---------------------------------------------"
oci lb load-balancer list -c $COMP_OCID|jq -r -C  '.data[]|(["NAME","OCID","IP-ADDRESS","IS-PUBLIC?"] | (., map(length*"-"))), ( [."display-name", .id, ."ip-addresses"[]."ip-address", ."ip-addresses"[]."is-public"]) | @tsv'|column -t
echo -e "\n"
read -p "KINDLY CHOOSE THE APPROPRIATE OCID: " OCID_LB
echo -e "\n"
green_color "FOUND BELOW BACKENDSETS"
green_color "-----------------------"
oci lb backend-set list --load-balancer-id $OCID_LB|jq -r -C '.data[].backends|(["IP-ADDRESS","PORT","WEIGHT"] | (., map(length*"-"))), (.[] | [."ip-address", .port, .weight]) | @tsv'|column -t
