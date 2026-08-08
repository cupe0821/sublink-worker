#!/system/bin/sh
# Output: profile|reason
PKG="$1"
[ -n "$PKG" ] || { echo "balanced|empty"; exit 0; }

HOME_PKG="$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1 | cut -d/ -f1)"
if [ "$PKG" = "$HOME_PKG" ]; then
  echo "launcher|home-activity"
  exit 0
fi

# Android ApplicationInfo.category values:
# -1 undefined, 0 game, 1 audio, 2 video, 3 image, 4 social,
# 5 news, 6 maps, 7 productivity, 8 accessibility.
CAT="$(dumpsys package "$PKG" 2>/dev/null | sed -n 's/.*category=\([^ ,}]*\).*/\1/p' | head -n 1)"
case "$CAT" in
  0|GAME|game) echo "game|android-category-game"; exit 0 ;;
  1|AUDIO|audio) echo "audio|android-category-audio"; exit 0 ;;
  2|VIDEO|video) echo "video|android-category-video"; exit 0 ;;
  4|SOCIAL|social) echo "chat|android-category-social"; exit 0 ;;
esac

LOW="$(echo "$PKG" | tr '[:upper:]' '[:lower:]')"
case "$LOW" in
  *youtube.music*|*music*|*spotify*|*podcast*|*soundcloud*|*qqmusic*|*cloudmusic*|*kugou*|*kuwo*|*audio*)
    echo "audio|package-heuristic" ;;
  *tmgp*|*mihoyo*|*hoyoverse*|*netease*game*|*supercell*|*riotgames*|*epicgames*|*unity*|*game*)
    echo "game|package-heuristic" ;;
  *bilibili*|*iqiyi*|*qqlive*|*youku*|*netflix*|*tiktok*|*douyin*|*primevideo*|*disney*|*hulu*|*youtube*|*video*)
    echo "video|package-heuristic" ;;
  *tencent.mm*|*wechat*|*weixin*|*telegram*|*whatsapp*|*discord*|*messenger*|*facebook.orca*|*tencent.mobileqq*|*tencent.tim*|*signal*|*social*|*chat*)
    echo "chat|package-heuristic" ;;
  *)
    echo "balanced|conservative-default" ;;
esac
