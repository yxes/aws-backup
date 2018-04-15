#!/bin/bash

########
#  Create backup AMIs for a given Instance
#
#  Steps:
#   1. initiate an AMI for the given instance
#   2. gather the return values to get the ami ID
#   3. monitor the current AMIs for that instance to go from 'pending' to 'available'
#      a. if it goes to 'failed' delete it and quit
#      b. if we go through 120 cycles (seconds?) then we are drunk and go home
#   4. We remove any old AMIs (and individually their associated snapshots)
#      a. loop through all known AMIs (based on their name)
#         1. if we uncover a failed one - remove it immediately
#      b. Create two hash variables - each using date as it's key - amis and snaps
#         1. if there is no date - it's the latest one so just use a huge number instead
#      c. sort the date keys by newest first
#      d. walk through the date keys and re-tag them or delete them as necessary
#
#   We LOG everything
#
# sample image creation call
# /usr/local/ec2/ec2-api-tools-1.7.5.1/bin/ec2-create-image --auth-dry-run --name Primary-20161201 --description "Automated Backup" i-17914583
#
######

source /home/ubuntu/.ec2

INSTANCE_NAME="XXXXXXXXX" # enter your instance name (make something up)
LOG_FILE="/home/ubuntu/log/$INSTANCE_NAME-ami.log"
EC2_DIR="/opt/ec2-api-tools/bin"
INSTANCE_ID="i-XXXXXXXXX" # get this from your list of ec2 instances 
TODAY=`date +"%Y%m%d"`
MAX_AMIS=2 # number of AMIs to keep on hand

# LOG ENTRY ORDER
ENTRY_ORDER=(0 1) # just IMAGE and ami-#####

AMI_CMD=`$EC2_DIR/ec2-create-image --name $INSTANCE_NAME-$TODAY --description "Automated Backup" $INSTANCE_ID`

## LOG IT
RET_VALUES=($AMI_CMD)

CURRENT_IMG=${RET_VALUES[1]}
echo "[$TODAY] CREATED IMAGE $CURRENT_IMG" >> $LOG_FILE

echo "logged results to $LOG_FILE"

showing_up=false
for i in $(seq 1 120); do
  line=`$EC2_DIR/ec2-describe-images --filter "image-id=$CURRENT_IMG"`
  entries=($line)
  if [ -z ${entries[0]} ]; then
     sleep 1
  else
     if [ "${entries[4]}" == "available" ]; then
        showing_up=true
        break
     elif [ "${entries[4]}" == "failed" ]; then
        $EC2_DIR/ec2-deregister ${entries[1]} >/dev/null 2>&1
        TS=`date +"%Y-%m-%dT%H:%M:%S%z"`
        echo "[$TS] DELETED failed AMI ${entries[1]}" >> $LOG_FILE
        exit
     fi
     sleep 1
  fi
done

if [ ! showing_up ]; then
   echo "[$TS] Current image [$CURRENT_IMG] isn't showing up... quitting" >> $LOG_FILE
   exit
fi

# TAG IT
$EC2_DIR/ec2-create-tags $CURRENT_IMG --tag="Name=DOMAINS" >/dev/null 2>&1

# REMOVE OLD AMIs
declare -A amis
declare -A snaps

OLD_IFS=$IFS
IFS=$'\n'

current_date=""

for line in $($EC2_DIR/ec2-describe-images --filter "name=$INSTANCE_NAME-*"); do
    IFS=$OLD_IFS
    entries=(${line})
    if [ "${entries[0]}" == "IMAGE" ]; then
       DATE=${entries[12]//[!0-9]/}
       if [ "${entries[4]}" == "failed" ]; then # if the ami failed - remove it and skip it
          $EC2_DIR/ec2-deregister ${entries[1]}
          TS=`date +"%Y-%m-%dT%H:%M:%S%z"`
       elif [ -z ${DATE} ]; then
          # this may not be created yet when we lookup - move it front and center
          # or we could be looking at a 'failed' ami
          current_date=99999999999999999
          amis["99999999999999999"]=${entries[1]}
       else
          current_date=$DATE
          amis[$DATE]=${entries[1]}
       fi
    elif [ "${entries[0]}" == "BLOCKDEVICEMAPPING" ]; then
       snaps[$current_date]=${entries[3]}
    fi
done

IFS=$OLD_IFS

## sort our keys
amis_keys=( $(
    for el in "${!amis[@]}"; do
        echo "$el"
    done | sort -rn -k3) )

COUNTER=1
for date in "${amis_keys[@]}"; do
    if [ "$COUNTER" -gt "$MAX_AMIS" ]; then
        TS=`date +"%Y-%m-%dT%H:%M:%S%z"`
        echo "[$TS] DELETED AMI ${amis["$date"]}" >> $LOG_FILE
        $EC2_DIR/ec2-deregister ${amis["$date"]} >/dev/null 2>&1
        $EC2_DIR/ec2-delete-snapshot ${snaps["$date"]} >/dev/null 2>&1
        sleep 1
    else
        if [ "$date" == "${amis_keys[0]}" ]; then
           $EC2_DIR/ec2-create-tags ${amis["$date"]} --tag="Name=DOMAINS" >/dev/null 2>&1
           $EC2_DIR/ec2-create-tags ${snaps["$date"]} --tag="Name=DOMAINS" >/dev/null 2>&1
        elif [ "$date" == "${amis_keys[1]}" ]; then
           $EC2_DIR/ec2-create-tags ${amis["$date"]} --tag="Name=domains" >/dev/null 2>&1
           $EC2_DIR/ec2-create-tags ${snaps["$date"]} --tag="Name=domains" >/dev/null 2>&1
        else
           $EC2_DIR/ec2-create-tags ${amis["$date"]} --tag="Name=domains-old" >/dev/null 2>&1
           $EC2_DIR/ec2-create-tags ${snaps["$date"]} --tag="Name=domains-old" >/dev/null 2>&1
        fi
    fi
    COUNTER=$(($COUNTER+1))
done |
sort -rn -k3

echo "removed old images keeping $MAX_AMIS"
echo "done."