# Description

Shell script which creates incremental plesk and owncloud backups with duply for amazon S3 storage.

# Usage

####Install dependencies
```
$ sudo apt-get install mutt
$ sudo apt-get install python-pip duplicity duply
$ sudo pip install boto
```

####Configure duply

```
$ duply owncloud create
$ duply plesk create
```

This creates ~/.duply/owncloud and ~/.duply/plesk config files.

####Inspiration / sample configuration for S3

Configure S3 access key / secret for both configs, apply your bucket target and insert password for encryption.

A good example can be found here:

https://benmatheja.de/2015/03/owncloud-s3-backup-einrichten/

Thanks to https://github.com/BenMatheja!

####Final

Customize following script variables for your needs

```
PLESKBACKUPFOLDER="/home/haus11/plesk/backup" #path to store plesk backups in
PLESKBACKUPPREFIX="pleskserver" #backup file prefix
PLESKBACKUPFILE="$PLESKBACKUPFOLDER/$TODAY.$PLESKBACKUPPREFIX.tar" #backup file naming
MAXPLESKBACKUPS=2 #maximum amount of plesk backups in folder

STATUSRECEIVER="info@haus11.org" #email address to send error/warning/success messages
LOGFOLDER="$PARENTPATH/logs"

ERRFILE="$LOGFOLDER/$FILENAME.$TODAY.error.log"
OUTFILE="$LOGFOLDER/$FILENAME.$TODAY.out.log"

```
