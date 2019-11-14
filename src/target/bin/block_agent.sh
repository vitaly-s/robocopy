#!/bin/sh

LOGFILE="/tmp/robocopy"

# synosata -info sdX | grep "Mount Path: " | sed "s/Mount Path: //"
# synosata -mount sdX fat share

# /dev/XXX on /volumeYYY/YYYshere type vfat (utf8,.....)
# mount | grep /dev/XXX | cut -d ' ' -f3 | xargs -r /usr/syno/bin/robocopy
# mount | grep /dev/XXX | sed 's/[^ ]* on //;s/ .*//'
# mount | grep /dev/XXX | sed -r 's/.*(\/volume[^ ]+).*/\1/'
# mount | grep /dev/XXX | sed -r 's/.* on ([^ ]*) .*/\1/'

run_copy() {
	DISKTYPE=`/usr/syno/bin/synodiskport -portcheck ${DEVNAME}`
	echo "------ ${SEQNUM} ------
DEVTYPE: ${DEVTYPE}
DEVNAME: ${DEVNAME}
DISKTYPE: ${DISKTYPE}
" >> ${LOGFILE}
	for TIMEOUT in 1 5 10 10 10 10
	do
#		echo "wait ${TIMEOUT}" >> ${LOGFILE}
		sleep ${TIMEOUT}
		case "$DISKTYPE" in
			USB|USBHUB)
				MOUNTPATH=`/usr/syno/bin/synousbdisk -info ${DEVNAME} | grep "Mount Path: " | sed "s/Mount Path: //"`
				;;
#			ESATA|SATA)
			ESATA)
				MOUNTPATH=`/usr/syno/bin/synosata -info ${DEVNAME} | grep "Mount Path: " | sed "s/Mount Path: //"`
				;;
		esac
		if [ -n "${MOUNTPATH}" ]
		then
			echo "RUN [${SEQNUM}]: robocopy ${MOUNTPATH}" >> ${LOGFILE}
			/usr/syno/bin/robocopy ${MOUNTPATH} &
#			/usr/syno/bin/synodsmnotify @administrators "robocopy" "Start copy from ${MOUNTPATH}." >> ${LOGFILE}
			return;
		fi
	done
	echo "Can not found mount path for '${DEVNAME}' [${SEQNUM}]" >> ${LOGFILE}
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


