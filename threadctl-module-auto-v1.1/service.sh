#!/system/bin/sh
MODDIR="${0%/*}"
(
  i=0
  while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$i" -lt 180 ]; do
    sleep 1
    i=$((i+1))
  done
  sleep 3
  "$MODDIR/scripts/start.sh" >/dev/null 2>&1
) &
