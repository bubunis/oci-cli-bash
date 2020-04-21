# Version: 1.0
# Usage:
#!/bin/bash
source ./curl.sh
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
##### HELP #####
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  green_color "THE PURPOSE OF THIS SCRIPT IS TO PROVIDE THE END USER AN EASY, ALTERNATE METHOD TO UPLOAD LARGE FILE(s) INTO OSS."
  exit 0;
fi;

FILE="list_OSS_Endpoints.txt"
echo -e "-- REGIONS --\n"
TXT=`cat $FILE|awk -F',' '{print $1}'`
green_color $TXT|sed 's/ /\n/g'
read -p "INSERT YOUR REGION: " REGION
REST_ENDPOINT=`cat $FILE|grep -i $REGION|awk -F'/' '{print $3}'`

if [ -z $REST_ENDPOINT ];then
	red_color "$REGION SEEMS TO BE INVALID. QUITTING.."
	exit 0
fi

read -p "INSERT YOUR NAMESPACE: " NAMESPACE
read -p "INSERT YOUR BUCKET NAME: " BUCKET


###### VALIDATING THE NAMESPACE AND BUCKET ######

VALID=`oci-curl $REST_ENDPOINT get "/n/$NAMESPACE/b/$BUCKET"|jq '.code'|tr -d '"'`
if [ $VALID = "BucketNotFound" ];then
	oci-curl $REST_ENDPOINT get "/n/$NAMESPACE/b/$BUCKET"|jq '.message'	
	red_color "QUTTING.."
	exit 0;
else
	echo -e "LISTING ALL OBJECTS IN THE BUCKET..."
	oci-curl $REST_ENDPOINT get "/n/$NAMESPACE/b/$BUCKET/o"|jq '.objects[].name'
fi


###### GETTING THE FILE DETAILS #############
read -p "INSERT THE ABSOLUTE PATH OOF THE FILE TO BE UPLOADED: " FILENAME
SIZE=`du -sh $FILENAME|awk '{print $1}'|cut -d'.' -f1`
read -p "INSERT THE NUMBER OF FILE CHUNKS YOU WANT TO PRODUCE: " CHUNKS

#### SPLITTING THE FILE ####
green_color "CREATING $CHUNKS FILES.."
split -n${CHUNKS} -d ${FILENAME} ${FILENAME}.Split
du -h ${FILENAME}.Split*

#### CREATING THE JSON FOR GETTING UPLOADID ####
read -p "INSERT THE NEW OBJECT NAME YOU WISH TO UPLOAD: " OBJ_NAME
echo "{\"object\":\"$OBJ_NAME\"}" |jq '.'|cat > partUpload.json
oci-curl objectstorage.us-ashburn-1.oraclecloud.com post ./my.json "/n/ocicustomeropshb/b/Mono-BUCKET-IAD/u"|jq
oci-curl $REST_ENDPOINT post ./partUpload.json "/n/$NAMESPACE/b/$BUCKET/u" |jq 
UPLOAD_ID=`oci-curl $REST_ENDPOINT post ./partUpload.json "/n/$NAMESPACE/b/$BUCKET/u" |jq '.uploadId'|tr -d '"'`
rm -f partUpload.json


#### UPLOADING SPLIT FILES ####
partNum=0
green_color "+++++ STARTING FILE UPLOAD +++++"
for part in ${FILENAME}.Split* 
do 
	partNum=$(($partNum + 1));
	SIZE=`du -s $part|awk '{print $1}'` 
	green_color "STARTING to UPLOAD $part, PartNUM: $partNum AT: `date`" 
	OLD_TIME=`date +%s`
	oci-curl $REST_ENDPOINT put $part "/n/$NAMESPACE/b/$BUCKET/u/$OBJ_NAME?uploadId=$UPLOAD_ID&uploadPartNum=$partNum"  &
	PID=$!
	i=1
	sp="/-\|"
	echo -n ' '
	while [ -d /proc/$PID ]
	do
		printf "\b${sp:i++%${#sp}:1}"
	done
	NEW_TIME=`date +%s`
	DIFF=$(($NEW_TIME - $OLD_TIME));
	SPEED=$(($SIZE / $DIFF / 1024));
	echo -e "\bUPLOAD OF $part COMPLETED AT - ${SPEED}M/sec AND TOTAL TIME TAKEN = $DIFF secs"
	#red_color "ENDED to UPLOAD $part, PartNUM: $partNum AT: `date`" 
done
wait
echo -e "\n"
green_color "UPLOAD STATUS.."
oci-curl $REST_ENDPOINT get /n/$NAMESPACE/b/$BUCKET/u/$OBJ_NAME?uploadId=$UPLOAD_ID|jq

#### PERFORMING COMMIT AND FINISHING UPLOAD ####

parts=$( oci-curl $REST_ENDPOINT GET /n/$NAMESPACE/b/$BUCKET/u/$OBJ_NAME?uploadId=$UPLOAD_ID| jq -r '.[] | (.partNumber|tostring) + " " +.etag' | while read partNum etag
do
echo '{"partNum": '$partNum',"etag": "'$etag'"}'
done
)
touch commitUpload.json
echo "$parts" | awk 'BEGIN{print "{\"partsToCommit\":["}NR>1{print ","}{print}END{print "]}"}' > commitUpload.json 

oci-curl $REST_ENDPOINT post commitUpload.json /n/$NAMESPACE/b/$BUCKET/u/$OBJ_NAME?uploadId=$UPLOAD_ID
echo -e "\n"
green_color " -- FINAL LIST OF OBJECTS AFTER UPLOAD -- "

oci-curl $REST_ENDPOINT get "/n/$NAMESPACE/b/$BUCKET/o" |jq '.objects[].name'
rm -f commitUpload.json

