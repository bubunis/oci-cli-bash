numCompare() {
   awk -v n1="$1" -v n2="$2" 'BEGIN {printf "%s " (n1<n2?"<":">=") " %s\n", n1, n2}'
}

kol=`printf "$(bc -l <<< "2147483648/1024")"`
lol=`df /mnt/sdb1 |awk '{print $4}'|tail -1`

output=`numCompare $kol $lol`
echo $output | grep -i '>' 1>/dev/null


if [ $? -eq 0 ];then
	echo "HELLO"
fi 
