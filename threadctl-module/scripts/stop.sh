#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
PIDFILE="$MODDIR/run/threadctl.pid"

[ -f "$PIDFILE" ] || exit 0
PID="$(cat "$PIDFILE" 2>/dev/null)"
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  i=0
  while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 10 ]; do
    sleep 1
    i=$((i + 1))
  done
  kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null || true
fi
rm -f "$PIDFILE"
