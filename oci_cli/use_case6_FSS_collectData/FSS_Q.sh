# Version: 1.1
# Usage:
#!/bin/bash

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



my_dir=$(pwd)
BS_OPT=$my_dir/output.txt
TEMP=$my_dir/temp1
TEMP1=$my_dir/temp2
CONF_TEMP=
>$TEMP
>$TEMP1
>$BS_OPT


ALL_NAME_C=`oci iam compartment list --all |jq -r '.data[].name'`
ALL_OCID_C=`oci iam compartment list --all |jq -r '.data[].id'`

####
# COPYING config FILE SAFELY
####

cp /$USER/.oci/config /$USER/.oci/config.BKP.$(date +"%m_%d_%Y")


####
# VALIDATING THE REGION
####
echo -e "DEFAULT REGION MENTIONED IN CONFIG FILE - `cat /$USER/.oci/config |grep -A5 DEFAULT|grep region|awk -F'=' '{print $2}'`"
read -p "DO YOU WANT TO CHANGE IT? [ Y/N ]: " RESP
if [ $RESP == "Y" ] || [ $RESP == "y" ];then
	OLD=`cat /$USER/.oci/config |grep -A5 DEFAULT| grep region|awk -F'=' '{print $2}'`
	echo -e "\n-----------------------"
	oci iam region-subscription list --all|jq -r '.data[]."region-name"'
	echo -e "------------------------\n"

	read -p "SELECT THE REGION WHICH YOU WISH TO CHOOSE: " region
	sed -i s/$OLD/$region/g /$USER/.oci/config 
fi


####
# VALIDATING THE COMPARTMENT
####
read -p "INSERT COMPARTMENT NAME or OCID: " COMP
if [ "`echo -e $ALL_NAME_C|grep -o $COMP|uniq`" == $COMP ];then
        COMP_OCID=`oci iam compartment list --all|grep -w -B4 $COMP|grep "ocid1.compartment"|awk -F':' '{print $2}'|tr -d '", '`

elif [ "`echo -e $ALL_OCID_C|grep -o $COMP|uniq`" == $COMP ];then
        COMP_OCID=$COMP
else
        red_color "$COMP DOESN'T MATCH WITH ANY COMPARTMENT"
        exit 0;
fi

####
# VALIDATING THE PRESENSE OF CONFIG FILE
####
if [ -z /$USER/.oci/config ];then
        red_color "SEEMS CONFIG FILE NOT PRESENT. PLEASE RUN -"
        green_color "oci setup config -- To SETUP THE CONFIG FILE"
        green_color "oci setup repair-file-permissions --file /$USER/.oci/config -- TO REPAIR THE SAME AFTER CONFIGURATION"
        exit 0;
fi

collect_FSS_basic_data(){

for i in `oci iam availability-domain list |jq -r '.data[].name'`
do

        green_color "SHOWING FSS IN $i"
        green_color "+++++++++++++++++"
        VAL=`oci fs mount-target list -c $COMP_OCID --availability-domain $i|wc -c`
        if [ $VAL -eq 0 ];then
                red_color "FSS NOT FOUND"
        else
                if [ -z "$2" ];then
			
			echo -e "\n+++++ FILE-SYSTEM DETAILS +++++\n"
			FILESYSTEM_OCID=(`oci fs file-system list -c $COMP_OCID --availability-domain $i| jq -r '.data[].id'|sed ':a;N;$!ba;s/\n/ /g'`)
			
			let z=0;
			while [ $z -lt ${#FILESYSTEM_OCID[@]} ]; do echo -e "FILESYSTEM-OCID: ${FILESYSTEM_OCID[$z]}"; EXPORT_OCID=`oci fs export list -c $COMP_OCID --file-system-id ${FILESYSTEM_OCID[$z]} |jq -r '.data[].id'`; echo -e "EXPORT-OCID: ${EXPORT_OCID}"; echo -e "EXPORT-OPTIONS: `oci fs export get --export-id ${EXPORT_OCID}|jq -r '.data."export-options"[]'`";z=`expr $z + 1`; done
			
			echo -e "\n+++++ MOUNT-TARGET DETAILS +++++\n"
			MOUNT_OCID=(`oci fs mount-target list -c $COMP_OCID --availability-domain $i| jq -r '.data[].id'|sed ':a;N;$!ba;s/\n/ /g'`)
                        
			let p=0;			
			while [ $p -lt ${#MOUNT_OCID[@]} ]; do echo -e "MOUNT-TARGET-OCID: ${MOUNT_OCID[$p]}"; IP_OCID=`oci fs mount-target get --mount-target-id ${MOUNT_OCID[$p]}|jq -r '.data."private-ip-ids"[]'`; MOUNT_IP=`oci network private-ip get --private-ip-id $IP_OCID|jq -r '.data."ip-address"'`;echo -e "MOUNT-TARGET-IP: $MOUNT_IP"; df -hP|grep $MOUNT_IP 1>/dev/null 2>/dev/null; if [ $? -eq 0 ];then IP_ADDR=`echo "$MOUNT_IP"`; fi; echo -e "EXPORT-SET-OCID: `oci fs mount-target get --mount-target-id ${MOUNT_OCID[$p]} |jq -r '.data."export-set-id"'`";p=`expr $p + 1`; done
                        
			OCID_VCN=`oci fs export-set list -c $COMP_OCID --availability-domain $i |jq -r '.data[]."vcn-id"'`
                        green_color "SHOWING RELATED SECURITY LIST IN $i"
                        green_color "++++++++++++++++++++++++++++++++++++++++++++++++++"
                        echo -e "\nEGRESS --"
                        oci network security-list list -c $COMP_OCID --vcn-id $OCID_VCN |jq '.data[]."egress-security-rules"[]."tcp-options"."destination-port-range"'|grep -v null|jq '.|select(.max==2050 or .max==111 or .max==2048)'

                        echo -e "\nINGRESS --"
                        oci network security-list list -c $COMP_OCID --vcn-id $OCID_VCN |jq '.data[]."ingress-security-rules"[]."tcp-options"."destination-port-range"'|grep -v null|jq '.|select(.max==2050 or .max==111 or .max==2048 or .max==2049)'

                elif [ $2 == "-v" ];then
                        oci fs file-system list -c $COMP_OCID --availability-domain $i
                        oci fs mount-target list -c $COMP_OCID --availability-domain $i
        fi
fi
done
}


sub_menu_performance(){
nderline=`tput smul`
nounderline=`tput rmul`
if [ -z $1 ]; then
        tput clear
        echo "1. E-Business Suite specific"
        echo "2. Rsync slow"
        echo "3. Backup of file system (Vendor backup like HP data protector, commvault) is slow"
	echo "4. Generic for any application"
        read -p "Enter selection: " sel
        tput clear
else
        sel=$1
fi



case $sel in
        1)
                echo -e "${underline=}E-Business Suite specific${nounderline=}\n"
                ;;
        2)
                echo -e "${underline=}Rsync slow {nounderline=}\n"
                ;;
        3)
                echo -e "${underline=}Backup of file system (Vendor backup like HP data protector, commvault) is slow${nounderline=}\n"
                ;;
	4)
		echo -e "${underline=}Generic for any application${nounderline=}\n"
		collect_FSS_basic_data
		green_color "MOUNTED FSS DIRECTORIES IN THIS SERVER"
		green_color "--------------------------------------"
		df -kh | grep ${IP_ADDR};echo -e "\n";
		green_color "MOUNT OPTIONS"
		green_color "-------------"
		mount | grep ${IP_ADDR}
		echo -e "\n"
		read -p "INSERT THE FSS-MOUNTPOINT WHERE SLOWNESS OBSERVED: " FSS_Mount 
		mkdir -p ${FSS_Mount}/dd 

		echo -e "\nTIME TAKEN FOR WRITING 4KB SIZED FILES 10 TIMES -"
		echo -e "------------------------------------------------"

		time (for x in $(seq 1 10); do dd if=/dev/zero of=${FSS_Mount}/dd/dummy_${x}.log bs=4K count=1 1>/dev/null 2>${TEMP}; cat ${TEMP}|grep -i copied |tee -a ${TEMP1}; done; sync)
		let SUM=0
		for i in `cat ${TEMP1}|grep -i copied|awk '{print $8}'`
		do
			VAL=`printf "%.3f\n" "$(bc -l <<< "${i}/1024")"`	
			SUM=`printf "%.3f\n" "$(bc -l <<< "$SUM+$VAL")"`
			
		done
		green_color "AVG SPEED: `printf "%.3f\n" "$(bc -l <<< "$SUM/10")"` MB/Sec"
		SUM=`printf "%.3f\n" "$(bc -l <<< "$SUM/10")"`
		>${TEMP1}
		

		echo -e "\nTIME TAKEN FOR WRITING 1MB SIZED FILES 10 TIMES -"
		echo -e "-------------------------------------------------"
		
		time (for x in $(seq 1 10); do dd if=/dev/zero of=${FSS_Mount}/dd/dummy_${x}.log bs=1M count=1 1>/dev/null 2>${TEMP}; cat ${TEMP}|grep -i copied |tee -a ${TEMP1}; done; sync)
		let SUM1=0
		for i in `cat ${TEMP1}|grep -i copied|awk '{print $8}'`
		do
			SUM1=`printf "%.3f\n" "$(bc -l <<< "$SUM1+$i")"`
		done
		green_color "AVG SPEED: `printf "%.3f\n" "$(bc -l <<< "$SUM1/10")"` MB/Sec"
		SUM1=`printf "%.3f\n" "$(bc -l <<< "$SUM1/10")"`
		>${TEMP1}
                echo -e "\nTIME TAKEN FOR WRITING 10MB SIZED FILES 10 TIMES -"
                echo -e "-------------------------------------------------"

                time (for x in $(seq 1 10); do dd if=/dev/zero of=${FSS_Mount}/dd/dummy_${x}.log bs=10M count=1 1>/dev/null 2>${TEMP}; cat ${TEMP}|grep -i copied|tee -a ${TEMP1} ; done; sync)
		let SUM2=0
		for i in `cat ${TEMP1}|grep -i copied|awk '{print $8}'`
		do
			SUM2=`printf "%.3f\n" "$(bc -l <<< "$SUM2+$i")"`
		done
		green_color "AVG SPEED: `printf "%.3f\n" "$(bc -l <<< "$SUM2/10")"` MB/Sec"	
		SUM2=`printf "%.3f\n" "$(bc -l <<< "$SUM2/10")"`
		if ((`bc <<< "$SUM2>$SUM1>$SUM"`)); then green_color "IT SEEMS FSS IS BEHAVING NORMALLY, NO ISSUE FOUND"; else red_color "IT SEEMS FSS IS NOT BEHAVING NORMALLY, PLEASE RAISE A MOS CASE WITH ORACLE SUPPORT"; fi

		rm -rf ${FSS_Mount}/dd
		rm -f ${TEMP}
		rm -f ${TEMP1}
		mv /$USER/.oci/config.BKP.$(date +"%m_%d_%Y") /$USER/.oci/config
		;;
        *)      echo "Not a valid option"
esac
}




underline=`tput smul`
nounderline=`tput rmul`
if [ -z $1 ]; then
        tput clear
	cat Banner_FSS

	echo "					1) For NFS server <MT_IP> not responding"
	echo "					2) For unable to mount"
        echo "                                  	3) For unable to unmount due to device busy"
        echo "                                  	4) For Performance related"
        echo
        read -p "Enter selection: " sel
        tput clear
else
        sel=$1
fi

case $sel in
        1)
                echo -e "${underline=}NFS server <MT_IP> not responding${nounderline=}\n"
		collect_FSS_basic_data
                ;;
	2)
		echo -e "${underline=}unable to mount${nounderline=}\n"
		;;
	3)
		echo -e "${underline=}unable to unmount due to device busy${nounderline=}\n"
		;;
	4)
		echo -e "${underline=}Performance Issue${nounderline=}\n"
		sub_menu_performance
		;;
        *)      echo "Not a valid option"
esac

