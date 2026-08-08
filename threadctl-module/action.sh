#!/system/bin/sh
MODDIR="${0%/*}"
echo "Restarting original threadctl-rs daemon..."
"$MODDIR/scripts/restart.sh"
sleep 1
"$MODDIR/scripts/status.sh"
