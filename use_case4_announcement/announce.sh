#!/bin/bash

read -p "Enter your tenancy OCID: " TEN_OCID
source ./curl.sh

echo -e $'\e[32;1m----------------------------------------__OCID__------------------------------------- | --_CN_-- | ------__START-TIME__------ | ------__END-TIME__--------\e[0m'

oci-curl announcements.us-ashburn-1.oraclecloud.com get "/20180904/announcements?compartmentId=$TEN_OCID"|jq -C -r '.items[] | [.id, .referenceTicketNumber, .timeOneValue, .timeTwoValue]|@csv'|sed 's/,/ /g'|column -t

echo -e "\n"

read -p "PLEASE ENTER THE OCID OF THE ANNOUNCEMENT THAT YOU WANT TO VIEW: " OCID_ANNOUNCE

oci-curl announcements.us-ashburn-1.oraclecloud.com get "/20180904/announcements/$OCID_ANNOUNCE?compartmentId=$TEN_OCID"|jq

ACK_STATUS=`oci-curl announcements.us-ashburn-1.oraclecloud.com get "/20180904/announcements/$OCID_ANNOUNCE/userStatus?compartmentId=$TEN_OCID"|jq '.timeAcknowledged'`

if [ $ACK_STATUS == "null" ];then
	echo -e "\nNO USER HAD ACKNOWLEDGED THE ABOVE ANNOUNCEMENT"
fi
