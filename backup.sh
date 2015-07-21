#!/bin/bash

TODAY=$(date +"%d%m%Y")
FILENAME=$(basename $0)
PARENTPATH=${0%/*}
MAXPLESKBACKUPS=2
STATUSRECEIVER="info@haus11.org"

LOGFOLDER="$PARENTPATH/logs"
PLESKBACKUPFOLDER="/home/haus11/plesk/backup"
PLESKBACKUPPREFIX="pleskserver"

ERRFILE="$LOGFOLDER/$FILENAME.$TODAY.error.log"
OUTFILE="$LOGFOLDER/$FILENAME.$TODAY.out.log"
PLESKBACKUPFILE="$PLESKBACKUPFOLDER/$TODAY.$PLESKBACKUPPREFIX.tar"

ERROR=false

sendEndSuccessStatus() {
   echo "All backups succeeded" | mutt -a $ERRFILE $OUTFILE -s "[H11-Server] Backups succeeded" -- $STATUSRECEIVER
}

sendEndFailStatus() {
   echo "One or more backups failed, please check the logs" | mutt -a $ERRFILE $OUTFILE -s "[H11-Server] Backups failed" -- $STATUSRECEIVER
}

sendFailStatus() {
   echo "Backup for $1 failed: $2" | mutt -a $ERRFILE $OUTFILE -s "[H11-Server] $1 backup failed" -- $STATUSRECEIVER
}

sendWarningStatus() {
   echo "Backup for $1 returned warning: $2" | mutt -a $ERRFILE $OUTFILE -s "[H11-Server] $1 backup returned warning" -- $STATUSRECEIVER
}

#create folders if not exists
mkdir -p $LOGFOLDER
mkdir -p $PLESKBACKUPFOLDER


#
# PLESK BACKUP
#

printf "#PLESK BACKUP\n" | tee -a $ERRFILE $OUTFILE

#count existing plesk backup files
FILECOUNT=$(find $PLESKBACKUPFOLDER -type f -name "*.$PLESKBACKUPPREFIX.tar" | wc -l)

printf "Found %d plesk backups in %s, %d allowed\n" $FILECOUNT $PLESKBACKUPFOLDER $MAXPLESKBACKUPS

PLESKBACKUPCLEANINGERROR=false

#check if old plesk backups has to be removed
if [ $FILECOUNT -gt $MAXPLESKBACKUPS ]; then

   #iterate old plesk backups and remove the oldest one (leave newest 2 backups in folder)
   ls -tr $PLESKBACKUPFOLDER/*.$PLESKBACKUPPREFIX.tar | head -n -$MAXPLESKBACKUPS | while read f; do
       rm -f "$f" 2>> $ERRFILE 1>>$OUTFILE
       echo "Removing old backup $(basename $f)"

       if [[ $? != 0 ]]; then
           echo "Removing old plesk backup $(basename $f) failed";
           PLESKBACKUPCLEANINGERROR=true
       fi
   done

   #send notification mail when backup removal failed
   if [ "$PLESKBACKUPCLEANINGERROR" = "true" ]; then
	sendWarningStatus "Plesk" "Could not remove one or more old backup files"
   fi
fi

#backup plesk data (whole server)
echo "Running plesk server backup"
/usr/local/psa/bin/pleskbackup server --output-file=$PLESKBACKUPFILE 2>> $ERRFILE 1>>$OUTFILE

#check if plesk backup returned with code 0
if [[ $? != 0 ]]; then
   echo "Plesk server backup failed";
   sendFailStatus "Plesk" "Failed to backup plesk data"
   ERROR=true
else
   # run plesk folder S3 backup
   echo "Running plesk data sync to S3"
   duply plesk backup 2>> $ERRFILE 1>>$OUTFILE

    if [[ $? != 0 ]]; then
       echo "Duply for plesk failed";
       sendFailStatus "Plesk" "Plesk data synchronisation with S3 failed"
       ERROR=true
    else
       echo "Plesk backup completed"
    fi
fi

printf "\n\n#OWNCLOUD BACKUP\n" | tee -a $ERRFILE $OUTFILE

# run owncloud data folder S3 backup
echo "Running owncloud data sync to S3"
duply owncloud backup 2>> $ERRFILE 1>>$OUTFILE

#check if duply returned with code 0
if [[ $? != 0 ]]; then
    echo "Duply for owncloud failed, exiting";
    sendFailStatus "OwnCloud" "OwnCloud data synchronisation with S3 failed"
    ERROR=true
else
    echo "OwnCloud backup completed"
fi

if [ "$ERROR" = "true" ]; then
    sendEndFailStatus
    echo "Some backups failed, exiting"
    exit $?
else
    sendEndSuccessStatus
    echo "All backups succeeded, exiting"
    exit 0;
fi
