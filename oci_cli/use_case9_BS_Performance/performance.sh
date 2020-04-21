#!/bin/bash

JS=`curl -sS -L http://169.254.169.254/opc/v1/instance/`
COMP_OCID_INSTANCE=`echo $JS|jq -r '.compartmentId'`
OCID_INSTANCE=`echo $JS|jq -r '.id'`
AVAIL_DOM=`echo $JS|jq -r '.availabilityDomain'`

my_dir=$(pwd)
BS_OPT=$my_dir/output.txt
>$BS_OPT


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

F_PROGRESS_STAT(){
	let sec=0
	while [ $PID -gt 1 ]
	do
		printf "."
		sec=$(( $sec + 1 ))
		sleep 1
		ps $PID 1>/dev/null
	if [ $? -eq 1 ];then
		break
	fi
	done
	red_color "..COMPLETED IN $sec SECS"
	echo -e "\n"
}


DISKS_IN_TOTAL=(`lsscsi | grep -v '-'|awk '{print $6}'`)

green_color "DISKS PRESENTED"
green_color "---------------"
echo -e "`oci compute boot-volume-attachment list --availability-domain $AVAIL_DOM -c $COMP_OCID_INSTANCE |jq -C -r '.data[]|"\(."boot-volume-id") \(.id)"'|grep $OCID_INSTANCE|awk '{print $1}'` >> /dev/oracleoci/oraclevda >> /dev/sda"
for i in `ls -la /dev/oracleoci/oraclevd*|awk '{print $9}'|sed 's/[[:digit:]]//g'|uniq|grep -v vda`
do
	echo -e "`oci compute volume-attachment list -c $COMP_OCID_INSTANCE |jq -r '.data[]| "\(.id) \(">>") \(.device) \(."instance-id")"'|grep $OCID_INSTANCE|awk '{print $1,$2,$3}'|grep $i` >> `realpath $i`"
done
echo -e "\n"
read -p "CHOOSE THE DISK WHERE YOU ARE FACING ISSUE (/dev/sda, /dev/sdb etc..): " DISK

##### IDENTIFYING WRONG DISK #####

if [ -z $DISK ];then
	red_color "SEEMS YOU HAVE NOT ENTERED ANY DISK. PLEASE RE-EXECUTE THE SCRIPT AND INSERT ONE FROM THE ABOVE LISTED DISKS. Quitting.." 
	exit;
fi

TOTAL_DISKS=`lsscsi | grep -v '-'|awk '{print $6}'`

echo $TOTAL_DISKS|sed 's/ /\n/g'|grep -x $DISK 1>/dev/null 2>/dev/null
if [ $? -gt 0 ];then
	red_color " ENTERED DISK IS NOT CORRECT. PLEASE RE-EXECUTE THE SCRIPT AND INSERT ONE FROM THE ABOVE LISTED DISKS. Quitting.."
	exit
fi

udevadm info --query=property --name=$DISK |grep -i virtio 1>/dev/null

if [ $? -eq 1 ];then
	counter=0
	echo -e "CHOOSEN $DISK IS iSCSI" | tee -a $BS_OPT
	IQN=`udevadm info --query=property --name=$DISK | grep -w ID_PATH|awk -F'iscsi-' '{print $2}'|awk -F'-lun' '{print$1}'`
	echo -e "IQN: $IQN" >> $BS_OPT
	for j in `ls -la /dev/oracleoci/oraclevd*|awk '{print $9}'|sed 's/[[:digit:]]//g'|uniq|grep -v vda`
	do
		local_d=`realpath $j`
		if [ "${local_d}" == "${DISK}" ];then
			ACT_DISK=$j
		fi
	done
	total_count=`oci compute volume-attachment list -c $COMP_OCID_INSTANCE|jq -r -c '.data[]|select( ."attachment-type"=="iscsi")'|wc -l`

	while [ $counter -lt $total_count ]
	do
		IQN1=`oci compute volume-attachment list -c $COMP_OCID_INSTANCE|jq -r -c '[.data[]|select( ."attachment-type"=="iscsi")]['$counter']'|jq -r '.iqn'`
		ACT_DISK1=`oci compute volume-attachment list -c $COMP_OCID_INSTANCE|jq -r -c '[.data[]|select( ."attachment-type"=="iscsi")]['$counter']'|jq -r '.device'`

		if [ "${IQN}" == "${IQN1}" ] && [ "${ACT_DISK}" == "${ACT_DISK1}" ];then
			echo "IQN and DISK are VERIFIED" | tee -a $BS_OPT
		fi
	counter=$(( $counter + 1 ))
	done

else

	echo -e "CHOOSEN $DISK IS PV" | tee -a $BS_OPT
fi

for item in "${DISKS_IN_TOTAL[@]}"
do
	if [ "$item" == "$DISK" ];then
		val=`iostat -x $DISK|tail -3|awk '{ { print $8 } }'|  tr -d '[A-Za-z-]'`
		printf "\nDEFAULT BLOCK SIZE - %.3f\n" "$(bc -l <<< "$val*512/1024")" | tee -a $BS_OPT
	fi
done	

#### 
# CHECKING YUM REACHABILITY #
####

region=`curl -s http://169.254.169.254/opc/v1/instance/ |jq -r '.canonicalRegionName'`
curl -X GET https://yum-$region.oracle.com 1>/dev/null 2>/dev/null
if [ $? -ne 0 ];then
	red_color "Follow the doc: How to Configure yum Repository in OCI Instance (Doc ID 2444552.1)"
	exit;
else
	sleep 1
	green_color "YUM SERVER RECHABILITY..OK"
fi

#### CHECKING CONFIG FILE: /etc/yum/vars/ociregion ####
config_check(){
OCIREGION=`curl -sfm 3 http://169.254.169.254/opc/v1/instance/ | jq -r '.region' | cut -d '-' -f 2`
VAL=`cat /etc/yum/vars/ociregion`
if [ "-${OCIREGION}" != "${VAL}" ];then
	red_color "PLEASE RECTIFY THE CONFIGURATION IN FILE - /etc/yum/vars/ociregion"
	exit
else
	sleep 1
	green_color "CONFIGURATION IN /etc/yum/vars/ociregion ..OK"
fi 
}
#### CHECKING IF fio INSTALLED #####

fio_check(){
which fio 2>/dev/null 1>/dev/null
if [ $? -eq 1 ];then
	red_color "FIO NOT INSTALLED. INSTALLING..."
	yum -y install fio* --quiet 1>/dev/null
else
	sleep 1
	green_color "FIO PRESENT...OK"

fi
}

#### CHECK OS ####
if cat /etc/*release | grep ^NAME | grep CentOS 1>/dev/null; then
	fio_check

elif cat /etc/*release | grep ^NAME | grep Oracle 1>/dev/null; then
        config_check
	fio_check
elif cat /etc/*release | grep ^NAME | grep Ubuntu 1>/dev/null; then
	fio_check
fi





##### MENU #####
show_menu(){
    normal=`echo "\033[m"`
    menu=`echo "\033[36m"` #Blue
    number=`echo "\033[33m"` #yellow
    bgred=`echo "\033[41m"`
    fgred=`echo "\033[31m"`
    printf "\n${menu}*********************************************${normal}\n"
    printf "${menu}**${number} 1)${menu} IOPS Performance Tests ${normal}\n"
    printf "${menu}**${number} 2)${menu} Throughput Performance Tests ${normal}\n"
    printf "${menu}**${number} 3)${menu} Latency Performance Tests ${normal}\n"
    printf "${menu}*********************************************${normal}\n"
    printf "Please enter a menu option and enter or ${fgred}q to exit. ${normal}"
    read opt
}

##### CASES TO RUN fio #####


show_menu
while [ $opt != '' ]
    do
    if [ $opt = '' ]; then
      exit;
    else
      case $opt in
	1)
		echo -e "++++++++++++++++++++++++" >> $BS_OPT
		echo -e " IOPS Performance Tests" >> $BS_OPT
		echo -e "++++++++++++++++++++++++" >> $BS_OPT
		echo -e "\nRUNNING RANDOM READS.." |tee -a $BS_OPT
		echo -e "----------------------\n" | tee -a $BS_OPT
  		fio --filename=$DISK --direct=1 --rw=randread --bs=4k --ioengine=libaio --iodepth=256 --runtime=20 --numjobs=4 --time_based --group_reporting --name=iops-test-job  --readonly 1>>output.txt &
		PID=$!
		F_PROGRESS_STAT $PID

		echo -e "\nRUNNING RANDOM FILE R/W" |tee -a $BS_OPT
		echo -e "-------------------------\n" | tee -a $BS_OPT
		read -p "INSERT THE SIZE (in GB) OF THE FILE YOU WISH TO USE FOR RUNNING THIS TEST - " SIZE
		read -p "THIS TEST REQUIRE CUSTOMER TO CREATE ONE SAMPLE DIRECTORY IN $1. IF YOU HAVE CREATED ONE, KINDLY INSERT - " MOUNT
		ls -ld $MOUNT 1>/dev/null 2>/dev/null
		if [ $? -gt 0 ];then
			red_color "$MOUNT: WRONG MOUNTPOINT"
			echo -e "CAN'T RUN fio.WRONG $MOUNT." >> $BS_OPT		
		else
                	fio --filename=$MOUNT/file --size=${SIZE}GB --direct=1 --rw=randrw --bs=4k --ioengine=libaio --iodepth=256 --runtime=20 --numjobs=4 --time_based --group_reporting --name=iops-test-job 1>>output.txt &
			PID=$!
			F_PROGRESS_STAT $PID
		fi

		#echo -e "\nRUNNING RANDOM R/W" | tee -a $BS_OPT
		#echo -e "--------------------\n" | tee -a $BS_OPT
		#read -p "WARNING: Do not run FIO tests with a write workload directly against working disk. Still wants to run [ Y/N ]? " RESPONSE
                #if [ $RESPONSE == "Y" ];then
                #        fio --filename=$1  --direct=1 --rw=randrw --bs=4k --ioengine=libaio --iodepth=256 --runtime=20 --numjobs=4 --time_based --group_reporting --name=iops-test-job 1>>output.txt &
		#	PID=$!
		#	F_PROGRESS_STAT $PID
		#fi

		echo -e "\nRUNNING SEQUENTIAL READS" | tee -a $BS_OPT
		echo -e "--------------------------\n" | tee -a $BS_OPT
		fio --filename=$DISK --direct=1 --rw=read --bs=4k --ioengine=libaio --iodepth=256 --runtime=20 --numjobs=4 --time_based --group_reporting --name=iops-test-job --readonly 1>>output.txt &
		PID=$!
                F_PROGRESS_STAT $PID

		show_menu;
		;;
	2)
                echo -e "+++++++++++++++++++++++++++++++" >> $BS_OPT
                echo -e " Throughput Performance Tests" >> $BS_OPT
                echo -e "+++++++++++++++++++++++++++++++" >> $BS_OPT
                echo -e "\nRUNNING RANDOM READS" |tee -a $BS_OPT
		echo -e "------------------------\n" |tee -a $BS_OPT
		fio --filename=device name --direct=1 --rw=randread --bs=64k --ioengine=libaio --iodepth=64 --runtime=120 --numjobs=4 --time_based --group_reporting --name=throughput-test-job --readonly 1>>output.txt &
		PID=$!
		F_PROGRESS_STAT $PID

                echo -e "\nRUNNING RANDOM FILE R/W" |tee -a $BS_OPT
                echo -e "-------------------------\n" | tee -a $BS_OPT
                read -p "THIS TEST REQUIRE CUSTOMER TO CREATE ONE SAMPLE DIRECTORY IN $1. IF YOU HAVE CREATED ONE, KINDLY INSERT - " MOUNT
                ls -ld $MOUNT 1>/dev/null 2>/dev/null
                if [ $? -gt 0 ];then
                        red_color "$MOUNT: WRONG MOUNTPOINT"
                        echo -e "CAN'T RUN fio.WRONG $MOUNT." >> $BS_OPT
                else
			fio --filename=$MOUNT/file --size=1GB --direct=1 --rw=randrw --bs=64k --ioengine=libaio --iodepth=64 --runtime=20 --numjobs=4 --time_based --group_reporting --name=throughput-test-job 1>>output.txt &
                        PID=$!
                        F_PROGRESS_STAT $PID
                fi

#                echo -e "\nRUNNING RANDOM R/W" | tee -a $BS_OPT
#                echo -e "--------------------\n" | tee -a $BS_OPT
#                read -p "WARNING: Do not run FIO tests with a write workload directly against working disk. Still wants to run [ Y/N ]? " RESPONSE
#                if [ $RESPONSE == "Y" ];then
#			fio --filename=$1 --direct=1 --rw=randrw --bs=64k --ioengine=libaio --iodepth=64 --runtime=120 --numjobs=4 --time_based --group_reporting --name=throughput-test-job 1>>output.txt &
#                        PID=$!
#                        F_PROGRESS_STAT $PID
#                fi		

                echo -e "\nRUNNING SEQUENTIAL READS" | tee -a $BS_OPT
                echo -e "--------------------------\n" | tee -a $BS_OPT
		fio --filename=$1 --direct=1 --rw=read --bs=64k --ioengine=libaio --iodepth=64 --runtime=120 --numjobs=4 --time_based --group_reporting --name=throughput-test-job --readonly 1>>output.txt &
                PID=$!
                F_PROGRESS_STAT $PID

		show_menu;
		;;
	3)
                echo -e "+++++++++++++++++++++++++++" >> $BS_OPT
                echo -e " Latency Performance Tests" >> $BS_OPT
                echo -e "+++++++++++++++++++++++++++" >> $BS_OPT
                echo -e "\nRUNNING RANDOM READS.." |tee -a $BS_OPT
                echo -e "----------------------\n" | tee -a $BS_OPT
		fio --filename=$1 --direct=1 --rw=randread --bs=4k --ioengine=libaio --iodepth=1 --numjobs=1 --time_based --group_reporting --name=readlatency-test-job --runtime=20 --readonly 1>>output.txt &
                PID=$!
                F_PROGRESS_STAT $PID

		echo -e "\nRUNNING RANDOM R/W" | tee -a $BS_OPT
                echo -e "--------------------\n" | tee -a $BS_OPT
                read -p "WARNING: Do not run FIO tests with a write workload directly against working disk. Still wants to run [ Y/N ]? " RESPONSE
                if [ $RESPONSE == "Y" ];then
			fio --filename=$1 --direct=1 --rw=randrw --bs=4k --ioengine=libaio --iodepth=1 --numjobs=1 --time_based --group_reporting --name=rwlatency-test-job --runtime=20 --readonly 1>>output.txt &
                        PID=$!
                        F_PROGRESS_STAT $PID
                fi
		show_menu;
		;;
	q) 	exit;
		;;
	*)
		red_color "WRONG INPUT"
		show_menu;
		;;	
  esac
fi
done
