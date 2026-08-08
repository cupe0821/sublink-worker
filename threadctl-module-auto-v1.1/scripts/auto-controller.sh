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
CLASSIFIER_VERSION="$(cat "$MODDIR/scripts/classifier.version" 2>/dev/null)"
[ -n "$CLASSIFIER_VERSION" ] || CLASSIFIER_VERSION=3

[ -f "$AUTO" ] || : > "$AUTO"
[ -f "$OVR" ] || : > "$OVR"
[ -f "$EN" ] || echo 1 > "$EN"

replace_auto_record() {
  P="$1"; PROF="$2"; WHY="$3"; TS="$4"; VER="$5"
  awk -F '\t' -v OFS='\t' -v p="$P" -v prof="$PROF" -v why="$WHY" -v ts="$TS" -v ver="$VER" '
    BEGIN{done=0}
    $1==p { if(!done){print p,prof,why,ts,ver; done=1} ; next }
    {print}
    END{if(!done) print p,prof,why,ts,ver}
  ' "$AUTO" > "$AUTO.tmp" && mv -f "$AUTO.tmp" "$AUTO"
}

classify_pkg() {
  P="$1"
  TRY=0
  while [ "$TRY" -lt 2 ]; do
    TRY=$((TRY+1))
    CLS="$(/system/bin/sh "$MODDIR/scripts/classify.sh" "$P" 2>>"$RUN/auto.log")"
    RC=$?
    BASE="${CLS%%|*}"
    REASON="${CLS#*|}"
    case "$BASE" in
      game|chat|video|launcher|audio|balanced|power-save)
        [ -n "$REASON" ] || REASON=classifier-no-reason
        return 0
        ;;
    esac
    echo "classifier attempt $TRY failed for $P rc=$RC output=$CLS" >> "$RUN/auto.log"
    sleep 1
  done
  BASE=balanced
  REASON=classifier-transient-error
  return 1
}

process_current() {
  PKG="$(/system/bin/sh "$MODDIR/scripts/detect-current.sh" 2>/dev/null)"
  [ -n "$PKG" ] || return 1

  # Root/module managers are deliberately not added to the scheduling config.
  case "$PKG" in
    me.weishu.kernelsu|com.topjohnwu.magisk|com.omarea.vtools) return 0 ;;
  esac

  EXIST="$(awk -F '\t' -v p="$PKG" '$1==p {print $0; exit}' "$AUTO" 2>/dev/null)"
  CHANGED=0
  NEED_CLASSIFY=0
  if [ -z "$EXIST" ]; then
    BASE=balanced
    REASON=new-app
    RECORD_VERSION=""
    NEED_CLASSIFY=1
  else
    BASE="$(printf '%s\n' "$EXIST" | cut -f2)"
    REASON="$(printf '%s\n' "$EXIST" | cut -f3)"
    RECORD_VERSION="$(printf '%s\n' "$EXIST" | cut -f5)"
    # Any record created by an older classifier is automatically re-evaluated.
    [ "$RECORD_VERSION" = "$CLASSIFIER_VERSION" ] || NEED_CLASSIFY=1
    case "$REASON" in
      migrated-v1.0|migration-v1.0|legacy-import|classifier-fallback|classifier-error-*|classifier-transient-error)
        NEED_CLASSIFY=1 ;;
    esac
  fi

  if [ "$NEED_CLASSIFY" = 1 ]; then
    if classify_pkg "$PKG"; then
      NOW="$(date +%s 2>/dev/null)"
      replace_auto_record "$PKG" "$BASE" "$REASON" "$NOW" "$CLASSIFIER_VERSION"
      CHANGED=1
      echo "auto-classified[v$CLASSIFIER_VERSION]: $PKG -> $BASE ($REASON)" >> "$RUN/auto.log"
    else
      # Never persist a failed classification. A transient failure must be
      # retried on the next loop rather than poisoning the app database.
      EFFECTIVE=balanced
      EFFECTIVE_REASON=classifier-transient-error
      NOW="$(date +%s 2>/dev/null)"
      printf '%s\t%s\t%s\t%s\n' "$PKG" "$EFFECTIVE" "$EFFECTIVE_REASON" "$NOW" > "$CURRENT.tmp"
      mv -f "$CURRENT.tmp" "$CURRENT"
      return 2
    fi
  fi

  EFFECTIVE="$BASE"
  OV="$(awk -F '\t' -v p="$PKG" '$1==p {v=$2} END{print v}' "$OVR" 2>/dev/null)"
  if [ -n "$OV" ]; then
    EFFECTIVE="$OV"
    EFFECTIVE_REASON=override
  else
    EFFECTIVE_REASON="$REASON"
  fi

  NOW="$(date +%s 2>/dev/null)"
  printf '%s\t%s\t%s\t%s\n' "$PKG" "$EFFECTIVE" "$EFFECTIVE_REASON" "$NOW" > "$CURRENT.tmp"
  mv -f "$CURRENT.tmp" "$CURRENT"

  if [ "$CHANGED" = 1 ]; then
    /system/bin/sh "$MODDIR/scripts/rebuild-config.sh" >/dev/null 2>&1
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
  PKG="$(/system/bin/sh "$MODDIR/scripts/detect-current.sh" 2>/dev/null)"
  if [ -n "$PKG" ] && [ "$PKG" != "$LAST" ]; then
    if process_current; then
      LAST="$PKG"
    else
      # Detection/classification failures are retried instead of being cached.
      LAST=""
    fi
  fi
  sleep 1
done
