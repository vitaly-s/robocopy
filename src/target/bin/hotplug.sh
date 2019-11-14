#!/bin/sh

if [ "$1" != "block" ]
then
	echo "incorrect '\$1' - aborting ..."
	exit
fi
if [ "$ACTION" != "add" ]
then
	echo "incorrect '\$ACTION' - aborting ..."
	exit
fi
if [ "$DEVTYPE" != "disk" ]
then
	echo "incorrect '\$DEVTYPE' - aborting ..."
	exit
fi
if [ -z "$DEVNAME" ]
then
	echo "incorrect '\$DEVNAME' - aborting ..."
	exit
fi 

#LOGFILE="/tmp/robocopy"
LOGFILE="/var/log/robocopy.log"

# synosata -info sdX | grep "Mount Path: " | sed "s/Mount Path: //"
# synosata -mount sdX fat share

# /dev/XXX on /volumeYYY/YYYshere type vfat (utf8,.....)
# mount | grep /dev/XXX | cut -d ' ' -f3 | xargs -r /usr/syno/bin/robocopy
# mount | grep /dev/XXX | sed 's/[^ ]* on //;s/ .*//'
# mount | grep /dev/XXX | sed -r 's/.*(\/volume[^ ]+).*/\1/'
# mount | grep /dev/XXX | sed -r 's/.* on ([^ ]*) .*/\1/'

DISKTYPE=`/usr/syno/bin/synodiskport -portcheck ${DEVNAME}`
#echo "--- [${SEQNUM}] DEVTYPE: ${DEVTYPE} DEVNAME: ${DEVNAME} DISKTYPE: ${DISKTYPE}" >> ${LOGFILE}
for i in $(seq 5 5 60)
do
#	echo "wait ${TIMEOUT}" >> ${LOGFILE}
#	sleep ${TIMEOUT}
	sleep 5
	case "$DISKTYPE" in
		USB|USBHUB)
#			MOUNTPATH=`/usr/syno/bin/synousbdisk -info ${DEVNAME} | grep "Mount Path: " | sed "s/Mount Path: //"`
			MOUNTPATH=`mount | grep /dev/${DEVNAME} | cut -d ' ' -f3 | xargs`
			;;
#		ESATA|SATA)
		ESATA)
#			MOUNTPATH=`/usr/syno/bin/synosata -info ${DEVNAME} | grep "Mount Path: " | sed "s/Mount Path: //"`
			MOUNTPATH=`mount | grep /dev/${DEVNAME} | cut -d ' ' -f3 | xargs`
#			echo "--- [${SEQNUM}] MOUNTPATH: ${MOUNTPATH}" >> ${LOGFILE}
			;;
		*)
			exit
			;;
	esac
	if [ -n "${MOUNTPATH}" ]
	then
		echo "RUN [${SEQNUM}] ${DEVNAME}: robocopy ${MOUNTPATH}" >> ${LOGFILE}
		/usr/syno/bin/robocopy ${MOUNTPATH} &
		exit;
	fi
done
echo "Can not found mount path for '${DEVNAME}' [${SEQNUM}] DEVTYPE: ${DEVTYPE} DISKTYPE: ${DISKTYPE}" >> ${LOGFILE}
