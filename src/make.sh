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
	
	rm -rf _spk_dst
	mkdir _spk_dst
#	mkdir _spk_dst/scripts

	echo "== Compress to package.tgz"
	cd target/
	tar czf ../_spk_dst/package.tgz *
	cd ..

	cp -af INFO _spk_dst/
	cp -af scripts _spk_dst/
#	cp -af WIZARD_UIFILES/* _spk_dst/WIZARD_UIFILES
	cp -af target/ui/images/icon_72.png _spk_dst/PACKAGE_ICON.PNG

	echo "== Compress to $SPK_FILE"
	cd _spk_dst/
	tar -cvf ../"$SPK_FILE" *
	cd ..
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
	rm_rf "_spk_dst"
#	rm_rf "_package_dst"
}

case $1 in
	clean)
		make_clean
	;;
	*)
		make
	;;
esac
