#!/system/bin/sh
PATH=/sbin:/system/sbin:/system/bin:/system/xbin

setprop persist.sys.usb.config mtp,adb
setprop amazon.fos_flags.noadbauth 1
