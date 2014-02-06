#!/bin/bash

BASEDIR=$(dirname "$(readlink -f "$0")")
BINDIR="$BASEDIR/bin"
BUILDDIR="$BASEDIR/build"
ASSETDIR="$BASEDIR/asset"
LISTDIR="$BASEDIR/list"
TMPDIR="$BASEDIR/tmp"
ERRORCOLOR=31
WARNCOLOR=36
INFOCOLOR=32
HEADCOLOR=35
R="{}" # Color Reset Mark

color_start() {
	if [[ ! -z $2 ]]; then
		echo -n "\\\\033\\[$1m"
	else
		echo -n "\033[$1m"
	fi
}

color_end() {
	echo -n "\033[0m"
}

color() {
	echo -n "$(color_start "$1")$2$(color_end)"
}

bold() {
	echo -n "$(color 1 "$1")$R"
}

puts() {
	local NEWLINE=
	if [[ ! -z "$2" ]]; then
		NEWLINE=-n
	fi
	echo -e $NEWLINE "$1"
}

error() {
	puts "$(color $HEADCOLOR "[ERROR]")   $(echo -n "$(color $ERRORCOLOR "$1")" | sed "s/$R/$(color_start $ERRORCOLOR 1)/")" 1>&2
	cleanup
	exit 1
}

warn() {
	puts "$(color $HEADCOLOR "[WARNING]") $(echo -n "$(color $WARNCOLOR "$1")" | sed "s/$R/$(color_start $WARNCOLOR 1)/")" $2
}

info() {
	puts "$(color $HEADCOLOR "[INFO]")    $(echo -n "$(color $INFOCOLOR "$1")" | sed "s/$R/$(color_start $INFOCOLOR 1)/")" $2
}

info_done() {
	puts " $(color $INFOCOLOR "Done.")"
}

delete() {
	local FILE
	local BASENAME
	local FILENAME="${1%\"}"
	FILENAME="${FILENAME#\"}"
	FILENAME="${FILENAME#/}"
	if [[ $FILENAME =~ ^[^/]+\.apk$ ]]; then
		FILENAME="system/app/$FILENAME"
	fi
	if [[ -z "$FILENAME" ]]; then
		return
	fi
	for FILE in $BUILDDIR/$FILENAME; do
		BASENAME="${FILE#$BUILDDIR/}"
		if [[ ! -w "$FILE" ]]; then
			warn "Cannot find file $(bold "$BASENAME") to delete."
		else
			rm -rf "$FILE" || error "Failed to delete $(bold "$BASENAME")."
			info "Deleted $(bold "$BASENAME")."
		fi
	done
}

copy() {
	local FILE
	local BASENAME
	local ASSET
	local DIR
	for FILE in $BUILDDIR/$1; do
		BASENAME="${FILE#$BUILDDIR/}"
		if [[ -w "$FILE" ]]; then
			warn "File $(bold "$BASENAME") already exists. Will be replaced."
		fi
		ASSET="$ASSETDIR/$BASENAME"
		if [[ ! -r "$ASSET" ]]; then
			error "Cannot find asset $(bold "$BASENAME")."
		fi
		DIR="$(dirname "$FILE")"
		mkdir -p "$DIR" && cp -rf "$ASSET" "$DIR" || error "Failed to copy $(bold "$BASENAME")."
		info "Copied $(bold "$BASENAME")."
	done
}

apk_res() {
	local FILE="$BUILDDIR/$1"
	local RESDIR="$ASSETDIR/$1"
	local TMP="$TMPDIR/$1"
	if [[ ! -f "$FILE" || ! -r "$FILE" ]]; then
		error "Cannot find apk $(bold "$1" "$ERRORCOLOR")."
	fi
	mkdir -p "$TMP"
	# unpack
	info "Unpacking apk $(bold "$1")..." 1
	unzip -qq "$FILE" -d "$TMP"
	if [[ $? -gt 0 ]]; then
		error "Cannot unpack $(bold "$1")."
	fi
	info_done
	# copy stuff
	if [[ ! -d "$RESDIR" ]]; then
		error "Cannot find resource for $(bold "$1")."
	fi
	info "Replacing resources..." 1
	cp -rf "$RESDIR/." "$TMP"
	info_done
	# pack
	info "Packing apk $(bold "$1")..." 1
	pushd "$TMP" > /dev/null
	zip -rqX "$TMP.zip" .
	popd > /dev/null
	info_done
	info "Zipaligning new apk..." 1
	$BINDIR/zipalign -f 4 "$TMP.zip" "$FILE"
	info_done
	rm -rf "$TMP.zip" "$TMP"
}

cleanup() {
	info "Cleaning up..." 1
	rm -rf "$TMPDIR"
	if [[ ! -z "$1" ]]; then
		rm -rf "$BUILDDIR"
	fi
	info_done
}

ZIPNAME=${1:?"Usage: $0 rom.zip"}
ZIPNAME=${ZIPNAME##*/}
ZIPNAME=${ZIPNAME%.zip}

if [[ ! -f "$1" || ! -r "$1" ]]; then
	error "Can't read file $(bold "$1")!"
fi

# create TMPDIR
mkdir -p "$TMPDIR"
# create BUILDDIR
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

# unzip to BUILDDIR
info "Unzipping $(bold "$1")..." 1
unzip -qq "$1" -d "$BUILDDIR"
if [[ $? -gt 0 ]]; then
	echo
	error "Failed to unzip ROM!"
fi
info_done

# delete files
grep -v '^\(#\|$\)' "$LISTDIR/delete" |cut -f1|cut -d' ' -f1 | while read -r LINE; do
	delete "$LINE"
done

# copy files
grep -v '^\(#\|$\)' "$LISTDIR/copy" | while read -r LINE; do
	copy "$LINE"
done

# other stuff

#info "Tweaking $(bold "build.prop")..." 1
#sed -i '/ro\.ril\.hsxpa/s/1/2/;/ro\.ril\.gprsclass/s/10/12/' "$BUILDDIR/system/build.prop"
#info_done

# JustArchi stock ROM stuff
UPDATER_SCRIPT="$BUILDDIR/META-INF/com/google/android/updater-script"
#mv "$BUILDDIR/system/bin/.ext/su" "$BUILDDIR/system/bin/.ext/.su"
#find -L "$BUILDDIR/system/bin/" -xtype l -exec rm -f {} \;
#rm "$BUILDDIR/system/bin/debuggerd" "$BUILDDIR/system/etc/init.d/00TEST_INITD"
#mv "$BUILDDIR/system/bin/debuggerd.real" "$BUILDDIR/system/bin/debuggerd"
rm "$BUILDDIR/boot.img"
find "$BUILDDIR" -type f -exec chmod 644 {} \;
find "$BUILDDIR" -type d -exec chmod 755 {} \;

# updater-script changes
sed -i '/boot\.img/d' "$UPDATER_SCRIPT"
sed -i '/unmount/d' "$UPDATER_SCRIPT"
#echo 'delete("/system/bin/freshsebool");' >> "$UPDATER_SCRIPT"
#echo 'delete("/system/bin/mkswap");' >> "$UPDATER_SCRIPT"
#echo 'delete("/system/bin/r");' >> "$UPDATER_SCRIPT"
#echo 'delete("/system/bin/readlink");' >> "$UPDATER_SCRIPT"
#echo 'delete("/system/bin/swapon");' >> "$UPDATER_SCRIPT"
#echo 'delete("/system/bin/swapoff");' >> "$UPDATER_SCRIPT"
# set Yank555 kernel init script permission
#echo 'set_metadata("/system/etc/init.kernel.sh", "uid", 0, "gid", 0, "mode", 0755, "capabilities", 0x0, "selabel", "u:object_r:system_file:s0");' >> "$UPDATER_SCRIPT"

# re-odex
echo 'ui_print("Re-odex all system jars and apks");' >> "$UPDATER_SCRIPT"
echo 'package_extract_dir("odex", "/tmp/odex");' >> "$UPDATER_SCRIPT"
echo 'set_perm_recursive(0, 0, 0755, 0755, "/tmp/odex");' >> "$UPDATER_SCRIPT"
echo 'assert(run_program("/tmp/odex/dexo.sh"));' >> "$UPDATER_SCRIPT"
echo 'delete_recursive("/tmp/odex");' >> "$UPDATER_SCRIPT"

echo 'unmount("/system");' >> "$UPDATER_SCRIPT"

# zip everything back together
info "Building final zip file..." 1
pushd "$BUILDDIR" > /dev/null
zip -9rqX "$BASEDIR/$ZIPNAME.cooked.zip" .
popd > /dev/null
info_done

cleanup 1

info "Saved as $(bold "$ZIPNAME.cooked.zip")."

# vim: noexpandtab
