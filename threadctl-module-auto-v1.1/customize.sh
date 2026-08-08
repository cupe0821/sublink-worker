#!/system/bin/sh
ui_print "*******************************"
ui_print " ThreadCtl-rs Auto WebUI v1.3"
ui_print "*******************************"
ui_print "- Original upstream Rust daemon"
ui_print "- Automatic foreground-app discovery"
ui_print "- Robust automatic profile classification"
ui_print "- Failed classifier records are retried"
ui_print "- Optional per-app override + advanced KDL"

case "$ARCH" in
  arm64|aarch64) ;;
  *) abort "This build supports ARM64 only (device arch: $ARCH)" ;;
esac

mkdir -p "$MODPATH/config" "$MODPATH/run"
OLD="/data/adb/modules/threadctl_rs_webui"

if [ -d "$OLD/config" ] && [ "$OLD" != "$MODPATH" ]; then
  [ -s "$OLD/config/advanced.kdl" ] && cp -f "$OLD/config/advanced.kdl" "$MODPATH/config/advanced.kdl"
  [ -s "$OLD/config/overrides.tsv" ] && cp -f "$OLD/config/overrides.tsv" "$MODPATH/config/overrides.tsv"
  [ -s "$OLD/config/exclude.txt" ] && cp -f "$OLD/config/exclude.txt" "$MODPATH/config/exclude.txt"
  [ -s "$OLD/config/auto-apps.tsv" ] && cp -f "$OLD/config/auto-apps.tsv" "$MODPATH/config/auto-apps.tsv"

  if [ ! -s "$MODPATH/config/auto-apps.tsv" ] && [ -s "$OLD/config/apps.tsv" ]; then
    NOW="$(date +%s 2>/dev/null)"
    TAB="$(printf '\t')"
    while IFS="$TAB" read -r PKG PROFILE REST; do
      [ -n "$PKG" ] || continue
      case "$PROFILE" in game|chat|video|launcher|audio|balanced|power-save) ;; *) continue ;; esac
      printf '%s\t%s\t%s\t%s\n' "$PKG" "$PROFILE" "migrated-v1.0" "$NOW" >> "$MODPATH/config/auto-apps.tsv"
    done < "$OLD/config/apps.tsv"
  fi
fi

[ -f "$MODPATH/config/auto-apps.tsv" ] || : > "$MODPATH/config/auto-apps.tsv"
[ -f "$MODPATH/config/overrides.tsv" ] || : > "$MODPATH/config/overrides.tsv"
[ -f "$MODPATH/config/exclude.txt" ] || : > "$MODPATH/config/exclude.txt"
[ -f "$MODPATH/config/advanced.kdl" ] || : > "$MODPATH/config/advanced.kdl"
[ -f "$MODPATH/config/auto.enabled" ] || echo 1 > "$MODPATH/config/auto.enabled"

set_perm "$MODPATH/bin/threadctl" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755

ui_print "- Install complete. Reboot, then open module WebUI."
