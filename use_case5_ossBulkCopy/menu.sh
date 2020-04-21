underline=`tput smul`
nounderline=`tput rmul`
if [ -z $1 ]; then
        tput clear
	cat banner
	
        echo
        echo
	echo "					1) CREATE BUCKET					16)CREATE MULTIPART UPLOAD"
	echo "					2) DELETE BUCKET"
        echo "                                  	3) GET BUCKET"
        echo "                                  	4) HEAD BUCKET"
        echo "                                 	5) LIST BUCKET"
        echo "                                  	6) UPDATE BUCKET"
        echo "                                  	7) GET NAMESPACE"
        echo "                                  	8) GET NAMESPACE METADATA"
        echo "                                  	9) UPDATE NAMESPACE METADATA"
        echo "                                       10) CREATE PRE-AUHTENTICATED REQUEST"
        echo "                                       11) DELETE PRE-AUHTENTICATED REQUEST"
        echo "                                       12) GET PRE-AUHTENTICATED REQUEST"
        echo "                                       13) LIST PRE-AUHTENTICATED REQUEST"
        echo
        read -p "Enter selection: " sel
        tput clear
else
        sel=$1
fi

case $sel in
        0)
                echo
                read -s -p "Enter password: " pw
                echo
                export PW=$pw
                pw_result=`~/rtm_scripts/lib/test_password.exp chr301ru20.usdc2.oraclecloud.com`
                if [ "$pw_result" = "BAD PASSWORD" ]; then unset PW;echo "Incorrect password entered";sleep 2;fi
                if [ -z $1 ]; then mm;fi
                ;;
        1)
                echo -e "${underline=}CREATE BUCKET${nounderline=}\n"
		source /script/use_case5_ossBulkCopy/bucket/bucket_master.sh;create_bucket
                ;;
	2) 	
		echo -e "${underline=}DELETE BUCKET${nounderline=}\n"
		source /script/use_case5_ossBulkCopy/bucket/bucket_master.sh;delete_bucket
		;;
	3)
		echo -e "${underline=}GET BUCKET${nounderline=}\n"
		source /script/use_case5_ossBulkCopy/bucket/bucket_master.sh;get_bucket
		;;
	5)
		echo -e "${underline=}LIST BUCKETS${nounderline=}\n"
		source /script/use_case5_ossBulkCopy/bucket/bucket_master.sh;list_bucket
		;;
	6)
		echo -e "${underline=}UPDATE BUCKET${nounderline=}\n"
		source /script/use_case5_ossBulkCopy/bucket/bucket_master.sh;update_bucket
		;;
        *)      echo "Not a valid option"
esac

