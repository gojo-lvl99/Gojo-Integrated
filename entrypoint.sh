#!/bin/sh

DURATION_RAW=${DURATION:-"unli"}
MAX_CONN=${MAX_CONN:-100}
MAINT_SECS=3600

parse_seconds() {
  case $1 in
    *h) echo $(( ${1%h} * 3600 )) ;;
    *d) echo $(( ${1%d} * 86400 )) ;;
    *m) echo $(( ${1%m} * 2592000 )) ;;
    *)  echo 0 ;;
  esac
}

DURATION_SECS=$(parse_seconds "$DURATION_RAW")

if [ "$DURATION_SECS" -gt 0 ] && [ "$DURATION_SECS" -le 604800 ]; then
  REFRESH_SECS=21600
else
  REFRESH_SECS=19800
fi

sed -i "s/MAX_CONN_HERE/$MAX_CONN/g" /etc/nginx/nginx.conf

/usr/bin/supervisord -c /etc/supervisord.conf &
sleep 2

START_EPOCH=$(date +%s)

gen_uuid() {
  cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | \
    sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)/\1-\2-\3-\4-/'
}
gen_pass()   { cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1; }
gen_suffix() { cat /dev/urandom | tr -dc 'a-z0-9'    | fold -w 8  | head -n 1; }

write_status() {
cat > /tmp/status.json << EOF
{
  "status": "$1",
  "uuid": "$2",
  "password": "$3",
  "suffix": {
    "vless_ws":  "$4",
    "vless_hu":  "$5",
    "vmess_ws":  "$6",
    "vmess_hu":  "$7",
    "trojan_ws": "$8",
    "trojan_hu": "$9",
    "ss_ws":     "${10}",
    "ss_hu":     "${11}"
  },
  "created":      $START_EPOCH,
  "next_refresh": ${12},
  "duration":     "$DURATION_RAW",
  "refresh_secs": $REFRESH_SECS
}
EOF
}

CYCLE=0
while true; do
  CYCLE=$(( CYCLE + 1 ))
  NOW=$(date +%s)

  if [ "$DURATION_SECS" -gt 0 ]; then
    ELAPSED=$(( NOW - START_EPOCH ))
    if [ "$ELAPSED" -ge "$DURATION_SECS" ]; then
      pkill xray 2>/dev/null || true
      cat > /tmp/status.json << EOF
{"status":"expired","created":$START_EPOCH,"duration":"$DURATION_RAW"}
EOF
      wait
      exit 0
    fi
  fi

  UUID=$(gen_uuid)
  PASS=$(gen_pass)
  S1=$(gen_suffix); S2=$(gen_suffix); S3=$(gen_suffix); S4=$(gen_suffix)
  S5=$(gen_suffix); S6=$(gen_suffix); S7=$(gen_suffix); S8=$(gen_suffix)

  sed \
    -e "s/PLACEHOLDER_UUID/$UUID/g" \
    -e "s/PLACEHOLDER_PASSWORD/$PASS/g" \
    -e "s/PLACEHOLDER_S1/$S1/g" \
    -e "s/PLACEHOLDER_S2/$S2/g" \
    -e "s/PLACEHOLDER_S3/$S3/g" \
    -e "s/PLACEHOLDER_S4/$S4/g" \
    -e "s/PLACEHOLDER_S5/$S5/g" \
    -e "s/PLACEHOLDER_S6/$S6/g" \
    -e "s/PLACEHOLDER_S7/$S7/g" \
    -e "s/PLACEHOLDER_S8/$S8/g" \
    /etc/xray/config.json > /tmp/xray-config.json

  pkill -SIGTERM xray 2>/dev/null || true
  sleep 1
  trap '' PIPE
  xray run -config /tmp/xray-config.json &

  NEXT=$(( $(date +%s) + REFRESH_SECS ))
  write_status "online" "$UUID" "$PASS" \
    "$S1" "$S2" "$S3" "$S4" "$S5" "$S6" "$S7" "$S8" "$NEXT"

  sleep $REFRESH_SECS

  pkill -SIGTERM xray 2>/dev/null || true
  sleep 1
  MAINT_END=$(( $(date +%s) + MAINT_SECS ))
  cat > /tmp/status.json << EOF
{"status":"maintenance","created":$START_EPOCH,"next_refresh":$MAINT_END,"duration":"$DURATION_RAW"}
EOF
  sleep $MAINT_SECS
done
