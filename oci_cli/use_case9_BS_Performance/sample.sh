counter=0
IQN=iqn.2015-12.com.oracleiaas:6075bc08-eac4-4bf3-949c-3664e2210912
ACT_DISK=/dev/oracleoci/oraclevdb

total_count=`oci compute volume-attachment list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a|jq -r -c '.data[]|select( ."attachment-type"=="iscsi")'|wc -l`

while [ $counter -lt $total_count ]
do
	IQN1=`oci compute volume-attachment list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a|jq -r -c '[.data[]|select( ."attachment-type"=="iscsi")]['$counter']'|jq -r '.iqn'`
	ACT_DISK1=`oci compute volume-attachment list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a|jq -r -c '[.data[]|select( ."attachment-type"=="iscsi")]['$counter']'|jq -r '.device'`

	if [ "${IQN}" == "${IQN1}" ] && [ "${ACT_DISK}" == "${ACT_DISK1}" ];then
		echo "IQN and DISK are VERIFIED"
	fi
	counter=$(( $counter + 1 ))
done
