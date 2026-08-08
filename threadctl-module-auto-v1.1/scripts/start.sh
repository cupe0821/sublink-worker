#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
RUN="$MODDIR/run"
CFG="$MODDIR/config"
mkdir -p "$RUN" "$CFG"

BIN="$MODDIR/bin/threadctl"
[ -x "$BIN" ] || { echo "fatal: native bin/threadctl missing or not executable" >> "$RUN/threadctl.log"; exit 1; }

# v1.2: repair v1.0-imported records before daemon start so the WebUI/KDL
# does not remain stuck on legacy balanced values.
"$MODDIR/scripts/reclassify-legacy.sh" >/dev/null 2>&1

# Do one foreground discovery before starting so the initial KDL normally
# already contains the app visible at boot (usually the launcher).
"$MODDIR/scripts/auto-controller.sh" --once >/dev/null 2>&1
"$MODDIR/scripts/rebuild-config.sh" || exit 1

if [ -f "$RUN/threadctl.pid" ]; then
  P="$(cat "$RUN/threadctl.pid" 2>/dev/null)"
  [ -n "$P" ] && kill -0 "$P" 2>/dev/null && : || rm -f "$RUN/threadctl.pid"
fi
if [ ! -f "$RUN/threadctl.pid" ]; then
  nohup "$BIN" -c "$CFG/threadctl.kdl" -s 2 >> "$RUN/threadctl.log" 2>&1 &
  echo $! > "$RUN/threadctl.pid"
fi

if [ -f "$RUN/auto.pid" ]; then
  P="$(cat "$RUN/auto.pid" 2>/dev/null)"
  [ -n "$P" ] && kill -0 "$P" 2>/dev/null && : || rm -f "$RUN/auto.pid"
fi
if [ ! -f "$RUN/auto.pid" ]; then
  nohup "$MODDIR/scripts/auto-controller.sh" >> "$RUN/auto.log" 2>&1 &
  echo $! > "$RUN/auto.pid"
fi

sleep 1
exit 0
