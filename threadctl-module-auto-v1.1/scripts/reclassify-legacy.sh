#!/system/bin/sh
# Reclassify every auto-generated record whose classifier schema is stale.
# Manual overrides are stored separately and therefore remain untouched.

MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
CFG="$MODDIR/config"
RUN="$MODDIR/run"
AUTO="$CFG/auto-apps.tsv"
TAB="$(printf '\t')"
FORCE="$1"
CLASSIFIER_VERSION="$(cat "$MODDIR/scripts/classifier.version" 2>/dev/null)"
[ -n "$CLASSIFIER_VERSION" ] || CLASSIFIER_VERSION=3

[ -s "$AUTO" ] || exit 0
TMP="$AUTO.reclass.tmp.$$"
: > "$TMP"
CHANGED=0
FAILED=0

classify_one() {
  P="$1"
  CLS="$(/system/bin/sh "$MODDIR/scripts/classify.sh" "$P" 2>>"$RUN/auto.log")"
  RC=$?
  NEWP="${CLS%%|*}"
  NEWR="${CLS#*|}"
  case "$NEWP" in
    game|chat|video|launcher|audio|balanced|power-save)
      [ -n "$NEWR" ] || NEWR=classifier-no-reason
      return 0 ;;
  esac
  echo "bulk classifier failure: $P rc=$RC output=$CLS" >> "$RUN/auto.log"
  return 1
}

while IFS="$TAB" read -r PKG PROFILE REASON TS VER REST; do
  [ -n "$PKG" ] || continue

  NEED=0
  [ "$FORCE" = "--all" ] && NEED=1
  [ "$VER" = "$CLASSIFIER_VERSION" ] || NEED=1
  case "$REASON" in
    migrated-v1.0|migration-v1.0|legacy-import|classifier-fallback|classifier-error-*|classifier-transient-error)
      NEED=1 ;;
  esac

  if [ "$NEED" = 1 ]; then
    if classify_one "$PKG"; then
      NOW="$(date +%s 2>/dev/null)"
      printf '%s\t%s\t%s\t%s\t%s\n' "$PKG" "$NEWP" "$NEWR" "$NOW" "$CLASSIFIER_VERSION" >> "$TMP"
      echo "bulk-reclassified[v$CLASSIFIER_VERSION]: $PKG -> $NEWP ($NEWR)" >> "$RUN/auto.log"
      CHANGED=1
    else
      # Keep the previous record stale so it will be retried later. Do not
      # replace it with balanced/classifier-fallback.
      printf '%s\t%s\t%s\t%s\t%s\n' "$PKG" "$PROFILE" "$REASON" "$TS" "$VER" >> "$TMP"
      FAILED=$((FAILED+1))
    fi
  else
    printf '%s\t%s\t%s\t%s\t%s\n' "$PKG" "$PROFILE" "$REASON" "$TS" "$VER" >> "$TMP"
  fi
done < "$AUTO"

mv -f "$TMP" "$AUTO"
if [ "$CHANGED" = 1 ]; then
  /system/bin/sh "$MODDIR/scripts/rebuild-config.sh" >/dev/null 2>&1
fi
printf '%s\n' "reclassify complete: changed=$CHANGED failed=$FAILED classifier=$CLASSIFIER_VERSION" >> "$RUN/auto.log"
exit 0
