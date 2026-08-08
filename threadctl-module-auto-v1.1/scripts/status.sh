#!/system/bin/sh
MODDIR="$(cd "${0%/*}/.." 2>/dev/null && pwd)"
RUN="$MODDIR/run"
status_one() {
  NAME="$1"; FILE="$2"
  if [ -f "$FILE" ]; then
    P="$(cat "$FILE" 2>/dev/null)"
    if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
      echo "$NAME=running pid=$P"
      return
    fi
  fi
  echo "$NAME=stopped"
}
status_one threadctl "$RUN/threadctl.pid"
status_one auto "$RUN/auto.pid"
if [ -f "$RUN/current.tsv" ]; then
  printf 'current='; cat "$RUN/current.tsv"
fi
