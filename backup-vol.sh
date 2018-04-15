#!/bin/bash

source /home/ubuntu/.ec2

VOL_NAME="XXXXXX"

LOG_FILE="/home/ubuntu/log/tote-snapshot.log"
EC2_DIR="/opt/ec2-api-tools/bin"
# NOTE: VOL does NOT include the "vol-" at the beginning
VOL="XXXXXXXXXX" # Volume ID - get this from EC2 -> Volumes (aws web)
TODAY=`date +"%Y%m%d"`
MAX_SNAPSHOTS=4 # number of snapshots to keep on hand

# LOG ENTRY ORDER
ENTRY_ORDER=(4 0 7 1 2 3 5 6 8)

SNAP=`$EC2_DIR/ec2-create-snapshot -d backup-tote-$TODAY vol-$VOL`

# LOG IT
RET_VALUES=($SNAP)

for idx in ${ENTRY_ORDER[@]}; do
    if [ "$idx" == "4" ]; then
        echo -n "[${RET_VALUES[$idx]}] " >> $LOG_FILE
    elif [ "$idx" == "7" ]; then
        echo -n "\"${RET_VALUES[$idx]}\" " >> $LOG_FILE
    else
        echo -n "${RET_VALUES[$idx]} " >> $LOG_FILE
    fi
done
echo "" >> $LOG_FILE

echo "logged results to $LOG_FILE"

# TAG IT
$EC2_DIR/ec2-create-tags ${RET_VALUES[1]} --tag="Name=$VOL_NAME Backup" >/dev/null 2>&1

# REMOVE OLD SNAPSHOTS
declare -A snapshots

OLD_IFS=$IFS
IFS=$'\n'

for line in $($EC2_DIR/ec2-describe-snapshots --filter "description=backup-$VOL_NAME-*"); do
    IFS=$OLD_IFS
    entries=(${line})
    if [ "${entries[0]}" == "SNAPSHOT" ]; then
       DATE=${entries[4]//[!0-9]/}
       snapshots[$DATE]=${entries[1]}
    fi
done

IFS=$OLD_IFS

# sort our keys
snapshot_keys=( $(
    for el in "${!snapshots[@]}"; do
        echo "$el"
    done | sort -rn -k3) )

COUNTER=1
for date in "${snapshot_keys[@]}"; do
    if [ "$COUNTER" -gt "$MAX_SNAPSHOTS" ]; then
        TS=`date +"%Y-%m-%dT%H:%M:%S%z"`
        echo "[$TS] SNAPSHOT ${snapshots["$date"]} DELETED" >> $LOG_FILE
        $EC2_DIR/ec2-delete-snapshot ${snapshots["$date"]} >/dev/null 2>&1
    fi
    COUNTER=$(($COUNTER+1))
done |
sort -rn -k3

echo "removed old snapshots keeping $MAX_SNAPSHOTS"
echo "done."