#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
RUNDIR="$MODDIR/run"
LOG="$RUNDIR/threadctl.log"
PIDFILE="$RUNDIR/threadctl.pid"
BIN="$MODDIR/bin/threadctl"
CFG="$MODDIR/config/threadctl.kdl"

mkdir -p "$RUNDIR"

if [ ! -x "$BIN" ]; then
  echo "[$(date '+%F %T')] FATAL: native bin/threadctl is missing or not executable" >> "$LOG"
  exit 1
fi

if [ -f "$PIDFILE" ]; then
  PID="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    exit 0
  fi
  rm -f "$PIDFILE"
fi

if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null)" -gt 524288 ]; then
  tail -c 262144 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
fi

"$MODDIR/scripts/rebuild-config.sh" >> "$LOG" 2>&1 || exit 1

echo "[$(date '+%F %T')] starting original threadctl-rs" >> "$LOG"
"$BIN" -v >> "$LOG" 2>&1 || true
nohup "$BIN" -c "$CFG" -s 2 >> "$LOG" 2>&1 &
PID=$!
echo "$PID" > "$PIDFILE"
sleep 1

if ! kill -0 "$PID" 2>/dev/null; then
  echo "[$(date '+%F %T')] FATAL: native threadctl exited during startup" >> "$LOG"
  rm -f "$PIDFILE"
  exit 1
fi

echo "[$(date '+%F %T')] native threadctl running, pid=$PID" >> "$LOG"
exit 0
