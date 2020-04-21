for i in `oci iam region list --all|jq -r '.data[].name'` 
do 
OLD=`cat ~/.oci/config |grep region|awk -F'=' '{print $2}'`
sed -i s/$OLD/$i/g ~/.oci/config 
cat ~/.oci/config; 
done
