#!/system/bin/sh
# Output exactly one line: profile|reason
PKG="$1"
[ -n "$PKG" ] || { echo "balanced|empty"; exit 0; }

LOW="$(printf '%s' "$PKG" | tr '[:upper:]' '[:lower:]' 2>/dev/null)"
[ -n "$LOW" ] || LOW="$PKG"

HOME_PKG="$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1 | cut -d/ -f1)"
if [ -n "$HOME_PKG" ] && [ "$PKG" = "$HOME_PKG" ]; then
  echo "launcher|home-activity"
  exit 0
fi

# Known package heuristics first. This keeps common apps reliable even when
# OEM package metadata/category is missing or vendor dumpsys output differs.
case "$LOW" in
  # Chat / IM / collaboration / conversational assistants
  *tencent.mm*|*wechat*|*weixin*|*telegram*|*whatsapp*|*discord*|*messenger*|*facebook.orca*|*tencent.mobileqq*|*tencent.tim*|*signal*|*alibaba.android.rimet*|*dingtalk*|*lark*|*feishu*|*wxwork*|*wework*|*aliyun.tongyi*|*tongyi*|*chatgpt*|*openai.chat*|*claude*|*gemini*|*doubao*|*deepseek*|*social*|*chat*)
    echo "chat|package-heuristic"; exit 0 ;;

  # Video / short-video / streaming
  *bilibili*|*iqiyi*|*qqlive*|*youku*|*netflix*|*tiktok*|*douyin*|*aweme*|*kuaishou*|*primevideo*|*disney*|*hulu*|*youtube*|*video*)
    echo "video|package-heuristic"; exit 0 ;;

  # Audio / music / podcasts / recorder
  *youtube.music*|*music*|*spotify*|*podcast*|*soundcloud*|*qqmusic*|*cloudmusic*|*netease.cloudmusic*|*kugou*|*kuwo*|*soundrecorder*|*recorder*|*audio*)
    echo "audio|package-heuristic"; exit 0 ;;

  # Games
  *tmgp*|*mihoyo*|*hoyoverse*|*hypergryph*|*kurogame*|*papegames*|*lilithgame*|*netease*game*|*supercell*|*riotgames*|*epicgames*|*unity*|*game*)
    echo "game|package-heuristic"; exit 0 ;;
esac

# Then try Android ApplicationInfo.category.
# -1 undefined, 0 game, 1 audio, 2 video, 3 image, 4 social,
# 5 news, 6 maps, 7 productivity, 8 accessibility.
CAT="$(dumpsys package "$PKG" 2>/dev/null | sed -n 's/.*category=\([^ ,}]*\).*/\1/p' | head -n 1)"
case "$CAT" in
  0|GAME|game) echo "game|android-category-game"; exit 0 ;;
  1|AUDIO|audio) echo "audio|android-category-audio"; exit 0 ;;
  2|VIDEO|video) echo "video|android-category-video"; exit 0 ;;
  4|SOCIAL|social) echo "chat|android-category-social"; exit 0 ;;
esac

echo "balanced|conservative-default"
exit 0
