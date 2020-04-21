source /script/curl.sh
>/tmp/test_file.txt

count=0
trap cleanup 1 2 3 6

cleanup()
{
  echo "Caught Signal ... cleaning up."
  echo -e "TOTAL NUMBER OF ERRORS: $count" >>/tmp/test_file.txt
  echo "Done cleanup ... quitting."
  exit 1
}

while true
 do
 HTTP_CODE=`oci-curl objectstorage.us-ashburn-1.oraclecloud.com GET /n/ocicustomeropshb/b/Mono-BUCKET-IAD/o -s -o /dev/null -w "%{http_code}"`
 if [ "$HTTP_CODE" -ne "200" ];then
	count=$((count+1))
	echo -e "-----------------------------------------" >> /tmp/test_file.txt
	echo -e "RECEIVED ERROR CODE: $HTTP_CODE AT: `date`" >>/tmp/test_file.txt 
 	echo -e "OPC-REQUEST-ID: `oci-curl objectstorage.us-ashburn-1.oraclecloud.com GET /n/ocicustomeropshb/b/Mono-BUCKET-IAD/o -i|grep 'opc-request-id:'|awk '{print $2}'`" >>/tmp/test_file.txt
	echo -e "-----------------------------------------" >> /tmp/test_file.txt
 fi
 done

