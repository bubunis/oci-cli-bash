#oci bv volume list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a |jq -C -r '.data[] | [.id, ."display-name", ."time-created"] | @csv'
#total=`oci bv volume list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a |jq -C -r '.data[].id'|sed 's/ /\n/g'`
#total_attach=`oci compute volume-attachment list -c ocid1.compartment.oc1..aaaaaaaagctfina6fj36f7tgr5gaf6zo5c2r5ijz4aakm3x2ive3jdwyv45a |jq -C -r '.data[]."volume-id"'`

#echo -e "showing total"
#echo $total


read -p "INSERT YOUR COMPARTMENT OCID: " COMP_OCID
for i in `oci bv volume list -c $COMP_OCID|jq -C -r '.data[].id'|sed 's/ /\n/g'`
do
	VAL=`oci compute volume-attachment list -c $COMP_OCID --volume-id $i|jq -C -r '.data[]."lifecycle-state"'`
	if [ "$VAL" == "ATTACHED" ];then
		echo -e "$i IS ATTACHED WITH: `oci compute volume-attachment list -c $COMP_OCID --volume-id $i|jq '.data[]."instance-id"'`"
 	else
		echo "$i NOT ATTACHED WITH ANY INSTANCE"	
	fi
done

