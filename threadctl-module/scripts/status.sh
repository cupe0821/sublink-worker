#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
PIDFILE="$MODDIR/run/threadctl.pid"
BIN="$MODDIR/bin/threadctl"
VER="unknown"
[ -x "$BIN" ] && VER="$($BIN -v 2>/dev/null | head -n 1)"

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "running|native|$PID|$VER"
    exit 0
  fi
fi

echo "stopped|native||$VER"
exit 1
