#!/system/bin/sh
# ThreadCtl Auto classifier v3
# Output exactly one line: profile|reason
# This script never changes scheduling itself. It only selects one of the
# upstream built-in profiles consumed by the original threadctl-rs daemon.

PKG="$1"
[ -n "$PKG" ] || { echo "balanced|empty-package"; exit 0; }

MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
CFG="$MODDIR/config"
LOW="$(printf '%s' "$PKG" | tr '[:upper:]' '[:lower:]' 2>/dev/null)"
[ -n "$LOW" ] || LOW="$PKG"

emit() {
  printf '%s|%s\n' "$1" "$2"
  exit 0
}

# 1) Exact active launcher detection has the highest priority.
HOME_PKG="$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | tail -n 1 | cut -d/ -f1)"
[ -n "$HOME_PKG" ] && [ "$PKG" = "$HOME_PKG" ] && emit launcher home-activity

# 2) Optional label cache. The WebUI fills this cache through KernelSU's
# package API, so classification can also use the human-readable app name.
LABEL="$(awk -F '\t' -v p="$PKG" '$1==p {print $2; exit}' "$CFG/labels.tsv" 2>/dev/null)"

# 3) One package-manager dump is shared by all metadata checks.
DUMP="$(dumpsys package "$PKG" 2>/dev/null)"

# Some ROMs expose the application label in dumpsys; use it only if the
# KernelSU label cache did not already provide one.
if [ -z "$LABEL" ]; then
  LABEL="$(printf '%s\n' "$DUMP" | sed -n \
    -e 's/.*Application Label:[[:space:]]*//p' \
    -e 's/.*application-label:[[:space:]]*//p' \
    -e 's/.*appLabel=[[:space:]]*//p' | head -n 1)"
fi

LABEL_LOW="$(printf '%s' "$LABEL" | tr '[:upper:]' '[:lower:]' 2>/dev/null)"
SIGNAL="$LOW $LABEL_LOW $LABEL"

# 4) Strong semantic signals from package id and app label. These are broad
# category patterns, not a per-device allowlist. More specific media types are
# checked before generic chat/AI patterns to avoid collisions such as YouTube Music.
case "$SIGNAL" in
  # Audio / music / podcast / recorder
  *youtube.music*|*spotify*|*qqmusic*|*cloudmusic*|*netease.cloudmusic*|*kugou*|*kuwo*|*podcast*|*radio*|*soundcloud*|*soundrecorder*|*voice.recorder*|*audiorecorder*|*music*|*audio*|*录音*|*音乐*|*播客*|*电台*)
    emit audio semantic-audio ;;

  # Video / streaming / short-video / TV
  *bilibili*|*iqiyi*|*qqlive*|*youku*|*netflix*|*tiktok*|*douyin*|*aweme*|*kuaishou*|*primevideo*|*disney*|*hulu*|*youtube*|*streaming*|*video*|*直播*|*视频*|*影视*|*电视*)
    emit video semantic-video ;;

  # Games / game engines / publishers
  *tmgp*|*mihoyo*|*hoyoverse*|*hypergryph*|*kurogame*|*papegames*|*lilithgame*|*supercell*|*riotgames*|*epicgames*|*netease*game*|*unity*|*unreal*|*game*|*游戏*)
    emit game semantic-game ;;

  # Chat / IM / collaboration / conversational AI
  *tencent.mm*|*wechat*|*weixin*|*telegram*|*whatsapp*|*discord*|*messenger*|*facebook.orca*|*tencent.mobileqq*|*tencent.tim*|*signal*|*alibaba.android.rimet*|*dingtalk*|*lark*|*feishu*|*wxwork*|*wework*|*slack*|*teams*|*skype*|*aliyun.tongyi*|*tongyi*|*chatgpt*|*openai.chat*|*claude*|*gemini*|*doubao*|*deepseek*|*social*|*chat*|*messaging*|*微信*|*qq*|*钉钉*|*飞书*|*聊天*|*千问*|*豆包*|*深度求索*)
    emit chat semantic-chat ;;
esac

# 5) Android ApplicationInfo.category. OEM dumpsys formats differ, so accept
# multiple textual forms and both numeric and symbolic category values.
CAT="$(printf '%s\n' "$DUMP" | sed -n \
  -e 's/.*category=\([^ ,}]*\).*/\1/p' \
  -e 's/.*category:[[:space:]]*\([^ ,}]*\).*/\1/p' | head -n 1)"
case "$CAT" in
  0|GAME|game) emit game android-category-game ;;
  1|AUDIO|audio) emit audio android-category-audio ;;
  2|VIDEO|video) emit video android-category-video ;;
  4|SOCIAL|social) emit chat android-category-social ;;
esac

# 6) Older Android/game declarations and TV/Leanback intent metadata.
printf '%s\n' "$DUMP" | grep -Eqi 'FLAG_IS_GAME|PRIVATE_FLAG_IS_GAME|android\.intent\.category\.GAME' && emit game android-game-flag
printf '%s\n' "$DUMP" | grep -Eqi 'android\.intent\.category\.LEANBACK_LAUNCHER|android\.software\.leanback' && emit video android-leanback

# 7) Media-browser services are a useful generic signal for music/audio apps
# when category metadata is absent. This is intentionally below video checks.
printf '%s\n' "$DUMP" | grep -Eqi 'android\.media\.browse\.MediaBrowserService|MediaLibraryService' && emit audio media-browser-service

# 8) Runtime game-engine evidence for the *currently running* package. This
# catches many games with opaque package names and no ApplicationInfo.category.
PIDS="$(pidof "$PKG" 2>/dev/null)"
for PID in $PIDS; do
  [ -r "/proc/$PID/maps" ] || continue
  grep -Eqi '/lib(unity|il2cpp|UE4|Unreal|godot)[^/]*\.so|/libgame[^/]*\.so' "/proc/$PID/maps" 2>/dev/null && emit game runtime-game-engine
  if [ -d "/proc/$PID/task" ]; then
    for COMM in /proc/$PID/task/*/comm; do
      [ -r "$COMM" ] || continue
      T="$(cat "$COMM" 2>/dev/null)"
      case "$T" in
        UnityMain|UnityGfxDevice*|GameThread|RenderThreadGame|UE4*|Unreal*|Godot*) emit game runtime-game-thread ;;
      esac
    done
  fi
done

# 9) Unknown foreground apps intentionally stay on the upstream balanced
# profile. This is a successful classification, not an error/fallback state.
emit balanced no-special-signal
