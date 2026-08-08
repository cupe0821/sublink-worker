#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
"$MODDIR/scripts/stop.sh"
sleep 1
"$MODDIR/scripts/start.sh"
