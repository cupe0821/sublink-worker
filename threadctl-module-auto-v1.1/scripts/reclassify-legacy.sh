#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
CFG="$MODDIR/config"
AUTO="$CFG/auto-apps.tsv"
OVR="$CFG/overrides.tsv"
TAB="$(printf '\t')"

[ -s "$AUTO" ] || exit 0
TMP="$AUTO.reclass.tmp"
: > "$TMP"
CHANGED=0

while IFS="$TAB" read -r PKG PROFILE REASON TS REST; do
  [ -n "$PKG" ] || continue

  # Manual overrides always win and are never rewritten here.
  OV="$(awk -F '\t' -v p="$PKG" '$1==p {v=$2} END{print v}' "$OVR" 2>/dev/null)"

  case "$REASON" in
    migrated-v1.0|migration-v1.0|legacy-import)
      CLS="$($MODDIR/scripts/classify.sh "$PKG" 2>/dev/null)"
      NEWP="${CLS%%|*}"
      NEWR="${CLS#*|}"
      case "$NEWP" in game|chat|video|launcher|audio|balanced|power-save) ;; *) NEWP=balanced; NEWR=classifier-fallback ;; esac
      NOW="$(date +%s 2>/dev/null)"
      printf '%s\t%s\t%s\t%s\n' "$PKG" "$NEWP" "$NEWR" "$NOW" >> "$TMP"
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
