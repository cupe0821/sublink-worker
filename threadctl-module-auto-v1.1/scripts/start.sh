#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
RUN="$MODDIR/run"
CFG="$MODDIR/config"
mkdir -p "$RUN" "$CFG"

BIN="$MODDIR/bin/threadctl"
[ -x "$BIN" ] || { echo "fatal: native bin/threadctl missing or not executable" >> "$RUN/threadctl.log"; exit 1; }

# Classify the currently visible app first so the initial config is useful even
# while an upgrade-wide database repair is running.
/system/bin/sh "$MODDIR/scripts/auto-controller.sh" --once >/dev/null 2>&1
/system/bin/sh "$MODDIR/scripts/rebuild-config.sh" || exit 1

if [ -f "$RUN/threadctl.pid" ]; then
  P="$(cat "$RUN/threadctl.pid" 2>/dev/null)"
  [ -n "$P" ] && kill -0 "$P" 2>/dev/null && : || rm -f "$RUN/threadctl.pid"
fi
if [ ! -f "$RUN/threadctl.pid" ]; then
  nohup "$BIN" -c "$CFG/threadctl.kdl" -s 2 >> "$RUN/threadctl.log" 2>&1 &
  echo $! > "$RUN/threadctl.pid"
fi

# v1.3 classifier database repair. The native daemon is already running at
# this point; if records change, rebuild-config triggers the daemon's normal
# upstream hot-reload path. No Rust scheduling logic is replaced here.
/system/bin/sh "$MODDIR/scripts/reclassify-legacy.sh" >/dev/null 2>&1

if [ -f "$RUN/auto.pid" ]; then
  P="$(cat "$RUN/auto.pid" 2>/dev/null)"
  [ -n "$P" ] && kill -0 "$P" 2>/dev/null && : || rm -f "$RUN/auto.pid"
fi
if [ ! -f "$RUN/auto.pid" ]; then
  nohup /system/bin/sh "$MODDIR/scripts/auto-controller.sh" >> "$RUN/auto.log" 2>&1 &
  echo $! > "$RUN/auto.pid"
fi

sleep 1
exit 0
