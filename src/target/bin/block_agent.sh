#!/bin/sh

#LOGFILE="/tmp/robocopy"
LOGFILE="/var/log/robocopy.log"
# synosata -info sdX | grep "Mount Path: " | sed "s/Mount Path: //"
# synosata -mount sdX fat share

# /dev/XXX on /volumeYYY/YYYshere type vfat (utf8,.....)
# mount | grep /dev/XXX | cut -d ' ' -f3 | xargs -r /usr/syno/bin/robocopy
# mount | grep /dev/XXX | sed 's/[^ ]* on //;s/ .*//'
# mount | grep /dev/XXX | sed -r 's/.*(\/volume[^ ]+).*/\1/'
# mount | grep /dev/XXX | sed -r 's/.* on ([^ ]*) .*/\1/'

run_copy() {
	DISKTYPE=`/usr/syno/bin/synodiskport -portcheck ${DEVNAME}`
#	echo "--- [${SEQNUM}] DEVTYPE: ${DEVTYPE} DEVNAME: ${DEVNAME} DISKTYPE: ${DISKTYPE}" >> ${LOGFILE}
#	for TIMEOUT in 1 5 10 10 10 10 
	for i in $(seq 5 5 60)
	do
#		echo "wait ${TIMEOUT}" >> ${LOGFILE}
#		sleep ${TIMEOUT}
		sleep 5
		case "$DISKTYPE" in
			USB|USBHUB)
#				MOUNTPATH=`/usr/syno/bin/synousbdisk -info ${DEVNAME} | grep "Mount Path: " | sed "s/Mount Path: //"`
				MOUNTPATH=`mount | grep /dev/${DEVNAME} | cut -d ' ' -f3 | xargs`
				;;
#			ESATA|SATA)
			ESATA)
#				MOUNTPATH=`/usr/syno/bin/synosata -info ${DEVNAME} | grep "Mount Path: " | sed "s/Mount Path: //"`
				MOUNTPATH=`mount | grep /dev/${DEVNAME} | cut -d ' ' -f3 | xargs`
#				echo "--- [${SEQNUM}] MOUNTPATH: ${MOUNTPATH}" >> ${LOGFILE}
				;;
		esac
		if [ -n "${MOUNTPATH}" ]
		then
			echo "RUN [${SEQNUM}] ${DEVNAME}: robocopy ${MOUNTPATH}" >> ${LOGFILE}
			/usr/syno/bin/robocopy ${MOUNTPATH} &
			return;
		fi
	done
	echo "Can not found mount path for '${DEVNAME}' [${SEQNUM}] DEVTYPE: ${DEVTYPE} DISKTYPE: ${DISKTYPE}" >> ${LOGFILE}
}

case "${ACTION}" in
	add)
		case "${DEVTYPE}" in 
#			disk|partition)
			disk)
				run_copy
				;;
			*)
				;;
		esac 
		;;
	remove)
#		rm ${LOGFILE}
		;;
esac
#	exit 0


