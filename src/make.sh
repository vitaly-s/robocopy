#!/bin/sh
# Copyright is Copyright

. `dirname "$0"`/INFO
SPK_FILE="${package}_${version}.spk"


pack_perl()
{
	# remove comments
	sed -r -i '/^\s*#[^!].*?$|^\s*#$/d' "$1"

}

pack_javascript()
{
	# remove comments
	#sed -r -i '/^\s*\/\/.*?$/d' "$1"
	perl -i -0pe 's|//.*?\n|\n|g; s#/\*(.|\n)*?\*/##g;' "$1"
	# remove empty strings
	sed -r -i '/^\s*$/d' "$1"
	#remove start space chars
	sed -r -i 's/^\s*//' "$1"
	# remove new line
	perl -i -0pe 's/\R//g' "$1"
}

pack_json()
{
	# remove comments
	#sed -r -i '/^\s*\/\/.*?$/d' "$1"
	perl -i -0pe 's|//.*?\n|\n|g; s#/\*(.|\n)*?\*/##g;' "$1"
	# remove empty strings
	sed -r -i '/^\s*$/d' "$1"
	#remove start space chars
	sed -r -i 's/^\s*//' "$1"
	# remove new line
	perl -i -0pe 's/\R//g' "$1"
}

pack_php()
{
	php -l "$1" >/dev/null 2>&1 >/dev/null
	if [ "$?" -eq 0 ]
	then
		echo "pack $1"
		head -n 1 "$1" | grep -e '^#!.*' > "$1.new"
		php -w "$1" >> "$1.new"
		mv -f "$1.new" "$1"
	fi
}

make()
{
	echo "Make ${SPK_FILE}..."
	if [ -f "$SPK_FILE" ]; then
		echo "$SPK_FILE" already exists
		exit 1
	fi
	
	echo "== Copy sources"
	rm -rf _tmp
	mkdir _tmp
	mkdir _tmp/package
	mkdir _tmp/spk
	
	cp -af target/* _tmp/package
	cp -af INFO _tmp/spk
	cp -af scripts _tmp/spk
	cp -af WIZARD_UIFILES _tmp/spk
	if [ -d conf ]; then
		cp -af conf _tmp/spk
		mkdir _tmp/package/conf_pkgcenter
		cp -af conf/* _tmp/package/conf_pkgcenter/
	fi
	
	find _tmp -name '*.bak' -delete

	cp -af target/ui/images/icon_72.png _tmp/spk/PACKAGE_ICON.PNG
	
	
	# check perl files
#	for srcfile in `grep -ril '^#!.*perl' ./_tmp/package/`
	for srcfile in `find ./_tmp/package/ -type f | grep -Ev 'lib/Image/|lib/File/' | grep -E '\.(pl|pm|cgi)'`
	do
		if [ "x${NEED_PACK}" == "xyes" ]; then
			pack_perl "$srcfile"
#			# remove comments
#			sed -r -i '/^\s*#[^!].*?$|^\s*#$/d' "$srcfile"
		fi
		# validate file
		perl -I./_tmp/package/lib -c "$srcfile" >/dev/null 2>&1
		if [ "$?" -ne 0 ]
		then
			echo "Error in \"${srcfile##*/}\""
			perl -I./_tmp/package/lib -c "$srcfile" 2>&1
			exit
		fi
		echo "    ${srcfile##*/} - OK"
	done
	
	# pack JS files
	if [ "x${NEED_PACK}" == "xyes" ]; then
		for srcfile in `find ./_tmp/package/ -type f -name '*.js'| grep -Ev 'lib/Image/|lib/File/'`
		do
			pack_javascript "$srcfile"
			# validate file
			echo "    ${srcfile##*/} - PACKED"
		done
	fi

	# pack config files
	if [ "x${NEED_PACK}" == "xyes" ]; then
		for srcfile in `find ./_tmp/package/ -type f -name 'config'| grep -Ev 'lib/Image/|lib/File/'`
		do
			pack_json "$srcfile"
			# validate file
			echo "    ${srcfile##*/} - PACKED"
		done
	fi

	# pack php files
	for phpfile in `grep -rl '<?php' ./_tmp/package/`
	do
		if [ "x${NEED_PACK}" == "xyes" ]; then
			pack_php "$phpfile"
		fi
		# validate file
		php -l "$phpfile" >/dev/null 2>&1 >/dev/null
		if [ "$?" -ne 0 ]
		then
			echo "Error in \"${phpfile##*/}\""
			exit
		fi
		echo "    ${phpfile##*/} - OK"
	done

	echo "== Compress to package.tgz"
	cd _tmp/package/
	tar czf ../spk/package.tgz --owner='' --group='' --mode=0755 *
	cd ../..

	#echo "extractsize=\"`du -sb ./_tmp/package | cut -f 1`\"" >> _tmp/spk/INFO
	#echo "checksum=\"` md5sum ./_tmp/spk/package.tgz | cut -f 1 -d ' '`\"" >> _tmp/spk/INFO
	#sed -i '/^create_time\s*=/d' _tmp/spk/INFO
	echo "create_time=\"`date +%Y%m%d-%H:%M:%S`\"" >> _tmp/spk/INFO
	
	echo "== Compress to $SPK_FILE"
	cd _tmp/spk/
	tar cf ../../"$SPK_FILE" --owner='' --group='' --mode=0755 *
	cd ../..
}

rm_rf()
{
	local path="$1"
	
	echo "Remove $path"
	rm -rf "$path"
}

make_clean()
{
	rm_rf "$SPK_FILE"
	rm_rf "_tmp"
}

case $1 in
	clean)
		make_clean
	;;
	debug)
		make
	;;
	*)
		NEED_PACK=yes
		make
	;;
esac
