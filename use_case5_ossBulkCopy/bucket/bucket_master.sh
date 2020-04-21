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

go_back(){
read -p "GO BACK TO THE MAIN MENU (Y/N): " resp
if [ $resp = "Y" ] || [ $resp = "y" ];then
	/script/use_case5_ossBulkCopy/menu.sh
else
	exit 0;
fi
}

get_bucket(){
read -p "INSERT YOUR NAMESPACE: " NAMESPACE
read -p "INSERT YOUR BUCKET NAME: " BUCKET
oci-curl $REST_ENDPOINT get /n/$NAMESPACE/b/$BUCKET|jq
go_back
}

list_bucket(){
read -p "INSERT YOUR NAMESPACE: " NAMESPACE
read -p "INSERT YOUR COMPARTMENT OCID: " COMP_OCID
oci-curl $REST_ENDPOINT get /n/$NAMESPACE/b/?compartmentId=$COMP_OCID|jq
go_back
}

delete_bucket(){
read -p "INSERT YOUR NAMESPACE: " NAMESPACE
read -p "INSERT YOUR COMPARTMENT OCID: " COMP_OCID
echo
green_color "++ LIST OF BUCKETS ++"
oci-curl $REST_ENDPOINT get /n/$NAMESPACE/b/?compartmentId=$COMP_OCID|jq '.[].name'

read -p "ENTER THE BUCKET NAME YOU WISH TO DELETE: " BUCK_NAME
oci-curl $REST_ENDPOINT delete /n/$NAMESPACE/b/$BUCK_NAME/
go_back
}

create_bucket(){
>bucket-create.json
read -p "INSERT YOUR NAMESPACE: " NAMESPACE
read -p "INSERT YOUR COMPARTMENT OCID: " COMP_OCID
read -p "INSERT THE NEW NAME OF THE BUCKET: " BUCKET_NAME
read -p "INSERT THE publicAccessType [ NoPublicAccess | ObjectRead | ObjectReadWithoutList ]: " PUBLIC
read -p "INSERT THE storageTier TYPE [ Standard| Archive ]: " STORAGE

green_color " ++ CREATING THE JSON ++ "

echo "{\"namespace\":\"${NAMESPACE}\",\"name\":\"${BUCKET_NAME}\",\"compartmentId\":\"${COMP_OCID}\",\"metadata\":{},\"publicAccessType\":\"${PUBLIC}\",\"storageTier\":\"${STORAGE}\",\"freeformTags\":{},\"definedTags\":{}}"|jq '.'|cat > bucket-create.json
echo
green_color " ++ CREATING THE BUCKET $BUCKET_NAME ++ "
oci-curl $REST_ENDPOINT post bucket-create.json /n/$NAMESPACE/b/ |jq

green_color " ++ CREATED ++"
go_back
}



