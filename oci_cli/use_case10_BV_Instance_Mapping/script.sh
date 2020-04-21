read -p "INSERT YOUR COMPARTMENT OCID: " COMP_OCID


JS=`curl -L http://169.254.169.254/opc/v1/instance/`


COMP_OCID_INSTANCE=`echo $JS|jq -r '.compartmentId'`
OCID_INSTANCE=`echo $JS|jq -r '.id'`
AVAIL_DOM=`echo $JS|jq -r '.availabilityDomain'`


for i in `oci bv volume list -c $COMP_OCID|jq -C -r '.data[].id'|sed 's/ /\n/g'`
do
       VAL=`oci compute volume-attachment list -c $COMP_OCID --volume-id $i|jq -C -r '.data[]."lifecycle-state"'`
       if [ "$VAL" == "ATTACHED" ];then
              echo -e "$i IS ATTACHED WITH: `oci compute volume-attachment list -c $COMP_OCID --volume-id $i|jq '.data[]."instance-id"'`"
      else
              echo "$i NOT ATTACHED WITH ANY INSTANCE"
       fi
done


oci compute boot-volume-attachment list --availability-domain $AVAIL_DOM -c $COMP_OCID_INSTANCE |jq -C -r '.data[]|"\(."boot-volume-id") \(.id)"'|grep $OCID_INSTANCE
 
