#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
CFG="$MODDIR/config"
RUN="$MODDIR/run"
mkdir -p "$CFG" "$RUN"
AUTO="$CFG/auto-apps.tsv"
OVR="$CFG/overrides.tsv"
EN="$CFG/auto.enabled"
CURRENT="$RUN/current.tsv"
MODE="${1:-loop}"
TAB="$(printf '\t')"

[ -f "$AUTO" ] || : > "$AUTO"
[ -f "$OVR" ] || : > "$OVR"
[ -f "$EN" ] || echo 1 > "$EN"

process_current() {
  PKG="$($MODDIR/scripts/detect-current.sh 2>/dev/null)"
  [ -n "$PKG" ] || return 1

  # Skip obvious root/module managers: they do not need performance policy.
  case "$PKG" in
    me.weishu.kernelsu|com.topjohnwu.magisk|com.omarea.vtools) return 0 ;;
  esac

  EXIST="$(awk -F '\t' -v p="$PKG" '$1==p {print $0; exit}' "$AUTO" 2>/dev/null)"
  CHANGED=0
  if [ -z "$EXIST" ]; then
    CLS="$($MODDIR/scripts/classify.sh "$PKG" 2>/dev/null)"
    BASE="${CLS%%|*}"
    REASON="${CLS#*|}"
    case "$BASE" in game|chat|video|launcher|audio|balanced|power-save) ;; *) BASE=balanced; REASON=classifier-fallback ;; esac
    NOW="$(date +%s 2>/dev/null)"
    printf '%s\t%s\t%s\t%s\n' "$PKG" "$BASE" "$REASON" "$NOW" >> "$AUTO"
    CHANGED=1
    echo "auto-discovered: $PKG -> $BASE ($REASON)"
  else
    BASE="$(printf '%s\n' "$EXIST" | cut -f2)"
    REASON="$(printf '%s\n' "$EXIST" | cut -f3)"
  fi

  EFFECTIVE="$BASE"
  OV="$(awk -F '\t' -v p="$PKG" '$1==p {v=$2} END{print v}' "$OVR" 2>/dev/null)"
  if [ -n "$OV" ]; then
    EFFECTIVE="$OV"
    EFFECTIVE_REASON="override"
  else
    EFFECTIVE_REASON="$REASON"
  fi

  NOW="$(date +%s 2>/dev/null)"
  printf '%s\t%s\t%s\t%s\n' "$PKG" "$EFFECTIVE" "$EFFECTIVE_REASON" "$NOW" > "$CURRENT.tmp"
  mv -f "$CURRENT.tmp" "$CURRENT"

  if [ "$CHANGED" = 1 ]; then
    "$MODDIR/scripts/rebuild-config.sh"
  fi
  return 0
}

if [ "$MODE" = "--once" ] || [ "$MODE" = "once" ]; then
  [ "$(cat "$EN" 2>/dev/null)" = "1" ] || exit 0
  i=0
  while [ "$i" -lt 10 ]; do
    process_current && exit 0
    sleep 1
    i=$((i+1))
  done
  exit 0
fi

LAST=""
while true; do
  if [ "$(cat "$EN" 2>/dev/null)" != "1" ]; then
    sleep 2
    continue
  fi
  PKG="$($MODDIR/scripts/detect-current.sh 2>/dev/null)"
  if [ -n "$PKG" ] && [ "$PKG" != "$LAST" ]; then
    process_current
    LAST="$PKG"
  fi
  sleep 1
 done
