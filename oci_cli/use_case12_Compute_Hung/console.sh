#!/bin/bash
#
# This script accepts <instance OCID> and <compartment OCID> as command parameters.
#
# It will interactively ask for them when not provided
# About OCIDs: https://docs.cloud.oracle.com/iaas/Content/General/Concepts/identifiers.htm
#
# Requires bash shell and OCI CLI installed and configured
# About the CLI: https://docs.cloud.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm
#
 
command -v oci >/dev/null 2>&1 || { echo >&2 "OCI CLI is not installed."; exit 1; }
resultsfile=~/consolehistory.txt
[[ -f $resultsfile ]] && rm -rf $resultsfile
date > $resultsfile
 
if [ "$#" == 2 ]; then
    instanceid=$1
    compartmentid=$2
else
    echo "This script accepts <instance OCID> and <compartment OCID> as command parameters. You can also enter them now." | tee -a $resultsfile
    printf "\nVM Instance OCID: " | tee -a $resultsfile
    read instanceid
    printf "\nCompartment OCID: " | tee -a $resultsfile
    read compartmentid
fi
 
oci compute instance get --instance-id $instanceid > /dev/null 2>&1
if [ $? -ne 0 ]; then
    printf "\n\n>> Invalid Instance OCID.\n\n" | tee -a $resultsfile
    exit
fi
oci iam compartment get --compartment-id $compartmentid > /dev/null 2>&1
if [ $? -ne 0 ]; then
    printf "\n\n>> Invalid Compartment OCID.\n\n" | tee -a $resultsfile
    exit
fi
 
echo Instance $instanceid | tee -a $resultsfile
echo Compartment $compartmentid | tee -a $resultsfile
errormessage=`mktemp /tmp/consolehistorytempfile.XXXXXX`
oci compute console-history capture --instance-id $instanceid 2> $errormessage | tee -a $resultsfile
 
if [ $? -ne 0 ]; then
    if [ $(grep "is currently being modified, try again later" $errormessage | wc -l ) -ne 0 ]; then
        echo "The instance is currently being modified, try again please." | tee -a $resultsfile
        exit
    fi
    if [ $(grep "reached limit of 10 console histories" $errormessage | wc -l) -ne 0 ]; then
    # if over the 10 console history object limit, delete the oldest 5
        echo "Limit of console history object limit has been reached. Making room for new ones..." | tee -a $resultsfile
        counter=1
        for consolehist in `oci compute console-history list --compartment-id $compartment --instance-id $instanceid --all | grep consolehistory | sed -n '/^      \"id/p'| awk -F: '{print $2}' | sed -e 's/[\",\ \"]//g'`
        do
            [ $counter -gt 5 ] && break       
            oci compute console-history delete --instance-console-history-id $consolehist --force 2>/dev/null | tee -a $resultsfile
            ((counter++))
        done
    fi
fi
echo "*** Available console history objects" | tee -a $resultsfile
for consolehist in `oci compute console-history list --compartment-id $compartment --instance-id $instanceid --all | grep consolehistory | sed -n '/^      \"id/p'| awk -F: '{print $2}' | sed -e 's/[\",\ \"]//g'`
do
    echo $consolehist | tee -a $resultsfile
    current=$consolehist
done
echo "*** Most current object:" | tee -a $resultsfile
oci compute console-history get --instance-console-history-id $current
echo "*** Most current console output:" | tee -a $resultsfile
printf "\n\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" | tee -a $resultsfile
oci compute console-history get-content --length 10000000 --file - --instance-console-history-id $current 2> $errormessage | tee -a $resultsfile
# sometimes it fails and returns "Console history cannot be retrieved in state Requested". Giving it a 2 second break.
if [ $? -ne 0 ]; then
    if [ $(grep "Console history cannot be retrieved in state Requested" $errormessage | wc -l ) -ne 0 ]; then
        sleep 2
        # if it fails again, just throw the error.
        oci compute console-history get-content --length 10000000 --file - --instance-console-history-id $current 2> $errormessage | tee -a $resultsfile
    fi
fi
printf "\n\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" | tee -a $resultsfile
# wrap up
printf "\n\n\nResults were also saved to $resultsfile\n"
rm -rf $errormessage
