#!/bin/bash




#./check_disk_size.sh
read -p "Please enter the device path to test [ e.g. /dev/sda OR /u01 ]: " DEV_PATH
read -p "Is it a disk or directory? [ Type "disk" for disk e.g. /dev/sdb OR "directory" e.g. /u01 for mountpoint ]: " OPT 



if [ $OPT == "disk" ];then
	fio --filename=$DEV_PATH --direct=1 --rw=randrw --bs=4k --ioengine=libaio --iodepth=64 --numjobs=4 --time_based --group_reporting --name=iops --runtime=60
else
	fio --name=randrw --rw=randrw --direct=1 --ioengine=libaio --bs=16k --numjobs=8 --rwmixread=90 --size=1G --runtime=600 --group_reporting --directory=$DEV_PATH
fi


