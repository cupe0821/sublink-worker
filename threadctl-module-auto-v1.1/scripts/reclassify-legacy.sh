#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
CFG="$MODDIR/config"
RUN="$MODDIR/run"
AUTO="$CFG/auto-apps.tsv"
OVR="$CFG/overrides.tsv"
TAB="$(printf '\t')"

[ -s "$AUTO" ] || exit 0
TMP="$AUTO.reclass.tmp"
: > "$TMP"
CHANGED=0

while IFS="$TAB" read -r PKG PROFILE REASON TS REST; do
  [ -n "$PKG" ] || continue

  case "$REASON" in
    migrated-v1.0|migration-v1.0|legacy-import|classifier-fallback|classifier-error-*)
      CLS="$(/system/bin/sh "$MODDIR/scripts/classify.sh" "$PKG" 2>>"$RUN/auto.log")"
      RC=$?
      NEWP="${CLS%%|*}"
      NEWR="${CLS#*|}"
      case "$NEWP" in
        game|chat|video|launcher|audio|balanced|power-save)
          [ -n "$NEWR" ] || NEWR=classifier-no-reason
          ;;
        *)
          NEWP=balanced
          if [ "$RC" -ne 0 ]; then NEWR="classifier-error-$RC"; else NEWR=classifier-fallback; fi
          ;;
      esac
      NOW="$(date +%s 2>/dev/null)"
      printf '%s\t%s\t%s\t%s\n' "$PKG" "$NEWP" "$NEWR" "$NOW" >> "$TMP"
      echo "bulk-reclassified: $PKG -> $NEWP ($NEWR)" >> "$RUN/auto.log"
      CHANGED=1
      ;;
    *)
      printf '%s\t%s\t%s\t%s\n' "$PKG" "$PROFILE" "$REASON" "$TS" >> "$TMP"
      ;;
  esac
done < "$AUTO"

mv -f "$TMP" "$AUTO"
if [ "$CHANGED" = 1 ]; then
  "$MODDIR/scripts/rebuild-config.sh" >/dev/null 2>&1
fi
exit 0
