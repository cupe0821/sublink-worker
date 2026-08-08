#!/system/bin/sh
MODDIR="${0%/*}"
"$MODDIR/scripts/restart.sh"
echo
echo "ThreadCtl-rs:"
"$MODDIR/scripts/status.sh"
