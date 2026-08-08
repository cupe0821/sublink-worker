#!/system/bin/sh

ui_print "***************************************"
ui_print " ThreadCtl-rs WebUI — Original Native"
ui_print "***************************************"

case "$ARCH" in
  arm64|aarch64) ;;
  *)
    ui_print "! Unsupported architecture: $ARCH"
    ui_print "! This build contains the original ARM64 Android daemon only."
    abort "ARM64 device required"
    ;;
esac

if [ ! -f "$MODPATH/bin/threadctl" ]; then
  abort "Native threadctl binary is missing from module"
fi

# Preserve user configuration when reinstalling/updating the module.
OLDMOD="/data/adb/modules/threadctl_rs_webui"
if [ -d "$OLDMOD/config" ] && [ "$OLDMOD" != "$MODPATH" ]; then
  ui_print "- Preserving existing ThreadCtl configuration"
  [ -f "$OLDMOD/config/apps.tsv" ] && cp -af "$OLDMOD/config/apps.tsv" "$MODPATH/config/apps.tsv"
  [ -f "$OLDMOD/config/advanced.kdl" ] && cp -af "$OLDMOD/config/advanced.kdl" "$MODPATH/config/advanced.kdl"
fi

set_perm "$MODPATH/bin/threadctl" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/scripts/start.sh" 0 0 0755
set_perm "$MODPATH/scripts/stop.sh" 0 0 0755
set_perm "$MODPATH/scripts/restart.sh" 0 0 0755
set_perm "$MODPATH/scripts/status.sh" 0 0 0755
set_perm "$MODPATH/scripts/rebuild-config.sh" 0 0 0755

"$MODPATH/scripts/rebuild-config.sh" >/dev/null 2>&1 || true

ui_print "- Upstream: StarfallSeas/threadctl-rs"
ui_print "- Native daemon: Android ARM64"
ui_print "- WebUI: app/profile manager + full KDL editor"
ui_print "- Reboot, then open this module's WebUI in KernelSU"
