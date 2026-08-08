#!/system/bin/sh
ui_print "*******************************"
ui_print " ThreadCtl-rs Auto WebUI v1.1"
ui_print "*******************************"
ui_print "- Original upstream Rust daemon"
ui_print "- Automatic foreground-app discovery"
ui_print "- Automatic profile classification"
ui_print "- Optional per-app override + advanced KDL"

case "$ARCH" in
  arm64|aarch64) ;;
  *) abort "This build supports ARM64 only (device arch: $ARCH)" ;;
esac

set_perm "$MODPATH/bin/threadctl" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755

mkdir -p "$MODPATH/config" "$MODPATH/run"
[ -f "$MODPATH/config/auto-apps.tsv" ] || : > "$MODPATH/config/auto-apps.tsv"
[ -f "$MODPATH/config/overrides.tsv" ] || : > "$MODPATH/config/overrides.tsv"
[ -f "$MODPATH/config/exclude.txt" ] || : > "$MODPATH/config/exclude.txt"
[ -f "$MODPATH/config/advanced.kdl" ] || : > "$MODPATH/config/advanced.kdl"
[ -f "$MODPATH/config/auto.enabled" ] || echo 1 > "$MODPATH/config/auto.enabled"

ui_print "- Install complete. Reboot, then open module WebUI."
