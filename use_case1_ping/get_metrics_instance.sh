# Version: 1.0
# Usage:
#!/bin/bash
source ./curl.sh
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

func_check_multiple(){
        VCN_OCI=$1
        COMP_OCI=$2
        ROUTETABLE_OCID=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns/$VCN_OCI"|jq '.defaultRouteTableId' 2>/dev/null`
        SECURITYLIST_OCID=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns/$VCN_OCI"|jq '.defaultSecurityListId' 2>/dev/null`
        CIDR_VCN=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns/$VCN_OCI"|jq '.cidrBlock' 2>/dev/null`
        LOC_PEER_GW=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/localPeeringGateways?vcnId=$VCN_OCI&compartmentId=$COMP_OCI"|jq '.[].id'`
        IGW=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/internetGateways?compartmentId=$COMP_OCID&vcnId=$VCN_OCID"|jq '.[].id'|tr -d '"'`         green_color "VCN details .."
        green_color "--------------"
        echo -e "$ROUTETABLE_OCID \n $SECURITYLIST_OCID \n $CIDR_VCN \n $LOC_PEER_GW \n $IGW"
}
 read -p "Enter your compartment OCID: " COMP_OCID

### CHECK The validity of the compartment given above ####
oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns?compartmentId=$COMP_OCID" | jq '.code'  2>/dev/null 1>/dev/null
ERR=`echo $?`
if [ $ERR -eq 5 ];then
	COUNT=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances?compartmentId=$COMP_OCID" | jq '.[]| .displayName + " " + .id + " " + .lifecycleState'|column -t|wc -l`
	echo -e "\n"
	green_color "SHOWING INSTANCE(S) CONFIGURED UNDER $COMP_OCID"
	green_color "------------------------------------------------------------------------------------------------------------------------"
	oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances?compartmentId=$COMP_OCID" | jq '.[]| .displayName + " " + .id + " " + .lifecycleState'|column -t
	if [ $COUNT -eq 1 ];then
		INST_OCI=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances?compartmentId=$COMP_OCID"|jq '.[].id'`
		sed -i '5s/.*/   "resourceId": "$INST_OCI"/' listMetrics.json
	else
		read -p "Enter the OCID of the desired instance: " INST_OCI
		sed -i '5s/.*/   "resourceId": "'"$INST_OCI"'"/' listMetrics.json
		echo -e "\n\e[1;34mBELOW METRICS FOUND FOR THIS INSTANCE -\e[0m"
		#oci-curl telemetry.us-ashburn-1.oraclecloud.com post ./listMetrics.json "/20180401/metrics/actions/listMetrics?compartmentId=$COMP_OCID"|jq '.[].name'
		METRIC_COUNT=`oci-curl telemetry.us-ashburn-1.oraclecloud.com post ./listMetrics.json "/20180401/metrics/actions/listMetrics?compartmentId=$COMP_OCID"|jq '.[].name'|wc -l`
		#echo $METRIC_COUNT
		if [ $METRIC_COUNT -ge 1 ];then
			oci-curl telemetry.us-ashburn-1.oraclecloud.com post ./listMetrics.json "/20180401/metrics/actions/listMetrics?compartmentId=$COMP_OCID"|jq '.[].name' 
			MON_STATUS=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/instances/$INST_OCI?compartmentId=$COMP_OCID"|jq '.agentConfig.isMonitoringDisabled'`
			if [ $MON_STATUS == 'false' ];then
				echo -e "\n\e[1;34mMONITORING IS ENABLED \e[0m"
			fi
		else
			red_color "NO METRIC FOUND"
			exit
		fi
	
	fi
fi

