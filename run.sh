#!/bin/bash

set -e

BOOT_IMG="boot.img"
AIK_DIR="AIK-Linux-mirror"
BOOT2ROOT_DIR="boot2root"

read_prop() {
    local prop_file="$1"
    local prop_key="$2"
    grep "^${prop_key}=" "$prop_file" 2>/dev/null | cut -d'=' -f2-
}

prop_exists() {
    local prop_file="$1"
    local prop_key="$2"
    grep -q "^${prop_key}=" "$prop_file" 2>/dev/null
}

update_prop() {
    local prop_file="$1"
    local prop_key="$2"
    local prop_value="$3"
    
    if prop_exists "$prop_file" "$prop_key"; then
        sed -i "s|^${prop_key}=.*|${prop_key}=${prop_value}|" "$prop_file"
    else
        echo "${prop_key}=${prop_value}" >> "$prop_file"
    fi
}

[ ! -f "$BOOT_IMG" ] && echo "Error: boot.img not found" && exit 1

echo "Unpacking boot image"
cd "$AIK_DIR"
./unpackimg.sh "../$BOOT_IMG" > /dev/null 2>&1

sudo chown -R $USER ramdisk

echo "Installing binaries"
mkdir -p ramdisk/sbin
cp "../$BOOT2ROOT_DIR/bin/adbd" ramdisk/sbin/
cp "../$BOOT2ROOT_DIR/bin/init.fosflags.sh" ramdisk/
chmod 755 ramdisk/sbin/adbd ramdisk/init.fosflags.sh

echo "Patching properties"
update_prop "ramdisk/default.prop" "ro.adb.secure" "0"
update_prop "ramdisk/default.prop" "ro.secure" "0"
update_prop "ramdisk/default.prop" "ro.debuggable" "1"
update_prop "ramdisk/default.prop" "persist.sys.usb.config" "mtp,adb"

if [ -f "ramdisk/sepolicy" ]; then
    echo "Patching SELinux policy"
    chmod +x "../$BOOT2ROOT_DIR/tools/sepolicy-inject"
    "../$BOOT2ROOT_DIR/tools/sepolicy-inject" -Z adbd -P ramdisk/sepolicy -o ramdisk/sepolicy 2>/dev/null
    "../$BOOT2ROOT_DIR/tools/sepolicy-inject" -s adbd -t adbd -c process -p setcurrent -P ramdisk/sepolicy -o ramdisk/sepolicy 2>/dev/null
    "../$BOOT2ROOT_DIR/tools/sepolicy-inject" -s adbd -t su -c process -p transition -P ramdisk/sepolicy -o ramdisk/sepolicy 2>/dev/null
    "../$BOOT2ROOT_DIR/tools/sepolicy-inject" -s su -t su -c process -p setcurrent -P ramdisk/sepolicy -o ramdisk/sepolicy 2>/dev/null
fi

FINGERPRINT=$(read_prop "ramdisk/default.prop" "ro.bootimage.build.fingerprint")

if [ -n "$FINGERPRINT" ]; then
    MODEL=$(echo "$FINGERPRINT" | cut -d'/' -f2)
    BUILD_INFO=$(echo "$FINGERPRINT" | cut -d'/' -f4 | cut -d':' -f1)
    OUTPUT_NAME="boot-${MODEL}-${BUILD_INFO}.img"
    echo "Device: $MODEL ($BUILD_INFO)"
else
    OUTPUT_NAME="boot-patched.img"
fi

echo "Repacking boot image"
./repackimg.sh > /dev/null 2>&1

cd ..
mv "$AIK_DIR/image-new.img" "$OUTPUT_NAME"

echo "Successfully created $OUTPUT_NAME"