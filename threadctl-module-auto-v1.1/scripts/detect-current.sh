#!/system/bin/sh
# Print the current foreground package. Prefer Android top-app cpuset because it
# follows the same foreground concept used by threadctl-rs' own foreground cache.

valid_pkg() {
  echo "$1" | grep -Eq '^[A-Za-z0-9_]+([.][A-Za-z0-9_]+)+$'
}

usable_pkg() {
  P="$1"
  valid_pkg "$P" || return 1
  pm path "$P" >/dev/null 2>&1 || return 1
  UIDV="$(dumpsys package "$P" 2>/dev/null | sed -n 's/.*userId=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  [ -z "$UIDV" ] && return 0
  [ "$UIDV" -ge 10000 ] 2>/dev/null
}

if [ -r /dev/cpuset/top-app/tasks ]; then
  for PID in $(cat /dev/cpuset/top-app/tasks 2>/dev/null); do
    [ -r "/proc/$PID/cmdline" ] || continue
    CMD="$(tr '\000' '\n' < "/proc/$PID/cmdline" 2>/dev/null | head -n 1)"
    PKG="${CMD%%:*}"
    if usable_pkg "$PKG"; then
      echo "$PKG"
      exit 0
    fi
  done
fi

PKG="$(dumpsys activity activities 2>/dev/null | grep -m 1 -E 'topResumedActivity|mResumedActivity' | sed -n 's#.* \([A-Za-z0-9._]*\)/[^ ]*.*#\1#p')"
if usable_pkg "$PKG"; then
  echo "$PKG"
  exit 0
fi

PKG="$(dumpsys window windows 2>/dev/null | grep -m 1 'mCurrentFocus' | sed -n 's#.* \([A-Za-z0-9._]*\)/[^ ]*.*#\1#p')"
if usable_pkg "$PKG"; then
  echo "$PKG"
  exit 0
fi

exit 1
