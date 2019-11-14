#!/bin/sh
# Copyright is Copyright

. INFO
SPK_FILE="${package}_${version}.spk"

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
#	cp -af WIZARD_UIFILES/* _tmp/spk/WIZARD_UIFILES
	cp -af target/ui/images/icon_72.png _tmp/spk/PACKAGE_ICON.PNG
	
	for phpfile in `grep -rl '<?php' ./_tmp/package/`
	do
		php -l "$phpfile" >/dev/null 2>&1 >/dev/null
		if [ "$?" -eq 0 ]
		then
			echo "pack $phpfile"
			head -n 1 "$phpfile" | grep -e '^#!.*' > "$phpfile.new"
			php -w "$phpfile" >> "$phpfile.new"
			mv -f "$phpfile.new" "$phpfile"
		fi
	done

	echo "== Compress to package.tgz"
	cd _tmp/package/
	tar czf ../spk/package.tgz *
	cd ../..


	echo "== Compress to $SPK_FILE"
	cd _tmp/spk/
	tar cf ../../"$SPK_FILE" *
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
	*)
		make
	;;
esac
