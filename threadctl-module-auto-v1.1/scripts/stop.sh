#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
RUN="$MODDIR/run"
for F in auto.pid threadctl.pid; do
  [ -f "$RUN/$F" ] || continue
  P="$(cat "$RUN/$F" 2>/dev/null)"
  if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
    kill "$P" 2>/dev/null
    i=0
    while kill -0 "$P" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 1; i=$((i+1)); done
    kill -9 "$P" 2>/dev/null || true
  fi
  rm -f "$RUN/$F"
done
