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

function check_firewall() {
	read -p "IS THIS THE SAME SERVER WHERE PROBLEM PERSISTS [Y/N]: " RESP
	if [ $RESP == "Y" ] || [ $RESP == "y" ];then
		VER=`cat /etc/*release|grep  VERSION_ID|awk -F"=" '{print $2}'|tr -d '"'|cut -d'.' -f1`
		if [ $VER -eq 7 ];then
			systemctl status firewalld|grep running 1>/dev/null
			if [ $? -eq 0 ];then
				echo -e "\n"
				red_color "FIREWALL IS ENABLED, PLEASE DISABLE IT OR CREATE A RULE FOR IT"
				green_color "STEPS TO ALLOW RULE FOR THE PORT $1"
				echo -e " firewall-cmd --permanent --zone=public --add-port=$1/tcp"
				echo -e " firewall-cmd --reload"
				echo -e " firewall-cmd --list-all"
			fi	
		fi			
	fi
}
func_check_multiple(){
        VCN_OCI=$1
        COMP_OCI=$2
        ROUTETABLE_OCID=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns/$VCN_OCI"|jq '.defaultRouteTableId' 2>/dev/null`
        SECURITYLIST_OCID=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns/$VCN_OCI"|jq '.defaultSecurityListId' |tr -d '"'`
        CIDR_VCN=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns/$VCN_OCI"|jq '.cidrBlock' 2>/dev/null`
        LOC_PEER_GW=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/localPeeringGateways?vcnId=$VCN_OCI&compartmentId=$COMP_OCI"|jq '.[].id'`
        IGW=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/internetGateways?compartmentId=$COMP_OCID&vcnId=$VCN_OCID"|jq '.[].id'|tr -d '"'`         	green_color "VCN details .."
        green_color "--------------"
        echo -e "$ROUTETABLE_OCID \n $SECURITYLIST_OCID \n $CIDR_VCN \n $LOC_PEER_GW \n $IGW"
	read -p "Enter the PORT number you wish to search: " PORT
	oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/securityLists/${SECURITYLIST_OCID}"|jq '.ingressSecurityRules[].tcpOptions.destinationPortRange.max'|grep -v null|grep $PORT 1>/dev/null
	VAL=`echo $?`
	if [ $VAL -eq 1 ];then
		red_color "ENTERED PORT: $PORT IS NOT PART OF THE INGRESS RULE OF:${SECURITYLIST_OCID}"
	else
		green_color "ENTERED PORT: $PORT IS PART OF THE INGRESS RULE OF:${SECURITYLIST_OCID}"
		check_firewall $PORT
		
	fi
}
 read -p "Enter your compartment OCID: " COMP_OCID

### CHECK The validity of the compartment given above ####
oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns?compartmentId=$COMP_OCID" | jq '.code'  2>/dev/null 1>/dev/null
ERR=`echo $?`
if [ $ERR -eq 5 ];then

	COUNT=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns?compartmentId=$COMP_OCID" | jq '.[]| .displayName + " " + .id'|column -t|wc -l`
	if [ $COUNT -eq 1 ];then
		VCN_OCI=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns?compartmentId=$COMP_OCID"|jq '.[].id'|tr -d '"'`
		func_check_multiple $VCN_OCI $COMP_OCID
		exit
	elif [ $COUNT -eq 0 ];then
		red_color "NO VCN PRESENT, Quitting.."
		exit
	else
		green_color "FOUND BELOW VCNs:"
		oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/vcns?compartmentId=$COMP_OCID" | jq '.[]| .displayName + " " + .id'|column -t
		read -p "Enter the OCID of the VCN which you want to check: " VCN_OCID
		func_check_multiple $VCN_OCID $COMP_OCID

		green_color "IPSEC DETAILS..."
		green_color "----------------"
		IPSEC_OCID=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/ipsecConnections?compartmentId=$COMP_OCID"|jq '.[].id'`
		CPE_OCID=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/ipsecConnections?compartmentId=$COMP_OCID"|jq '.[].cpeId'`
		DRG_OCID=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/ipsecConnections?compartmentId=$COMP_OCID"|jq '.[].drgId'|tr -d '"'`
		STATIC_RT=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/ipsecConnections?compartmentId=$COMP_OCID"|jq '.[].staticRoutes[]'`
		CPE_IP=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/ipsecConnections?compartmentId=$COMP_OCID"|jq '.[].cpeLocalIdentifier'`
		COMP_OCID=`echo $COMP_OCID|tr -d '"'`
		REM_PEER_GW=`oci-curl iaas.us-ashburn-1.oraclecloud.com get "/20160918/remotePeeringConnections?compartmentId=$COMP_OCID&drgId=$DRG_OCID"|jq '.[].id'|tr -d '"'`
		echo -e "$IPSEC_OCID \n $CPE_OCID \n $DRG_OCID \n $STATIC_RT \n $CPE_IP \n $REM_PEER_GW \n $IGW"
	fi
	exit
el
	echo "OCID:$COMP_OCID seems to be NOT Present. Quitting !!"
	exit
fi
