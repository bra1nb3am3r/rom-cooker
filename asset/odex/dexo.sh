#!/system/bin/sh

export BOOTCLASSPATH=/system/framework/core.jar:/system/framework/core-junit.jar:/system/framework/bouncycastle.jar:/system/framework/ext.jar:/system/framework/framework.jar:/system/framework/framework2.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/mms-common.jar:/system/framework/android.policy.jar:/system/framework/services.jar:/system/framework/apache-xml.jar:/system/framework/sec_edm.jar:/system/framework/seccamera.jar:/system/framework/scrollpause.jar:/system/framework/stayrotation.jar:/system/framework/smartfaceservice.jar:/system/framework/sc.jar:/system/framework/secocsp.jar:/system/framework/commonimsinterface.jar

B="/system/xbin/busybox"
SDIR=$($B dirname $($B readlink -f "$0"))

doodex() {
    odex=$($B echo "$1" | $B sed -e "s/\.$2/.odex/g")
    if $B [ ! -f "$odex" ]; then
        $B echo "Odexing $1..."
        $SDIR/dexopt-wrapper "$1" "$odex"
        if $B [ $? -eq 0 ]; then
#            $B echo "Removing 'classes.dex' from $1..."
#            $SDIR/zip -q -d "$1" classes.dex
#            if $B [ $2 == 'apk' ]; then
#                $B unzip -l "$1" | $B grep -qF /lib
#                if $B [ $? -eq 0 ]; then
#                    $B echo "Removing libs from $1..."
#                    $SDIR/zip -q -d "$1" *.so
#                fi;
#            fi
            $B echo "Setting Permission of $1..."
            $B chmod 644 "$1"
            $B echo "Setting Permission of $odex..."
            $B chmod 644 "$odex"
            $B echo
        fi;
    fi
}

zipalign() {
    $B echo "Zipalign $1..."
    $SDIR/zipalign -f 4 "$1" "$1.aligned"
    $B mv -f "$1.aligned" "$1"
    $B chmod 644 "$1"
}

# Framework
for i in $($B echo $BOOTCLASSPATH | $B sed 's/:/ /g')
do
    doodex "$i" 'jar'
done

# Framework Rest
for i in /system/framework/*.jar
do
    doodex "$i" 'jar'
done

# System apps
for i in /system/app/*.apk
do
    doodex "$i" 'apk'
    zipalign "$i"
done

# wipe Dalvik-cache
$B rm -f /data/dalvik-cache/*
