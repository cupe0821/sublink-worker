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

replace_auto_record() {
  P="$1"; PROF="$2"; WHY="$3"; TS="$4"
  awk -F '\t' -v OFS='\t' -v p="$P" -v prof="$PROF" -v why="$WHY" -v ts="$TS" '
    BEGIN{done=0}
    $1==p { if(!done){print p,prof,why,ts; done=1} ; next }
    {print}
    END{if(!done) print p,prof,why,ts}
  ' "$AUTO" > "$AUTO.tmp" && mv -f "$AUTO.tmp" "$AUTO"
}

classify_pkg() {
  P="$1"
  CLS="$(/system/bin/sh "$MODDIR/scripts/classify.sh" "$P" 2>>"$RUN/auto.log")"
  RC=$?
  BASE="${CLS%%|*}"
  REASON="${CLS#*|}"
  case "$BASE" in
    game|chat|video|launcher|audio|balanced|power-save)
      [ -n "$REASON" ] || REASON=classifier-no-reason
      ;;
    *)
      BASE=balanced
      if [ "$RC" -ne 0 ]; then REASON="classifier-error-$RC"; else REASON=classifier-fallback; fi
      ;;
  esac
}

process_current() {
  PKG="$($MODDIR/scripts/detect-current.sh 2>/dev/null)"
  [ -n "$PKG" ] || return 1

  case "$PKG" in
    me.weishu.kernelsu|com.topjohnwu.magisk|com.omarea.vtools) return 0 ;;
  esac

  EXIST="$(awk -F '\t' -v p="$PKG" '$1==p {print $0; exit}' "$AUTO" 2>/dev/null)"
  CHANGED=0
  NEED_CLASSIFY=0
  if [ -z "$EXIST" ]; then
    NEED_CLASSIFY=1
  else
    BASE="$(printf '%s\n' "$EXIST" | cut -f2)"
    REASON="$(printf '%s\n' "$EXIST" | cut -f3)"
    case "$REASON" in
      migrated-v1.0|migration-v1.0|legacy-import|classifier-fallback|classifier-error-*) NEED_CLASSIFY=1 ;;
    esac
  fi

  if [ "$NEED_CLASSIFY" = 1 ]; then
    classify_pkg "$PKG"
    NOW="$(date +%s 2>/dev/null)"
    replace_auto_record "$PKG" "$BASE" "$REASON" "$NOW"
    CHANGED=1
    echo "auto-classified: $PKG -> $BASE ($REASON)" >> "$RUN/auto.log"
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
