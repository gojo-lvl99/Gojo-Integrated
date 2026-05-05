#!/bin/sh

DURATION_RAW=${DURATION:-"unli"}
MAX_CONN=${MAX_CONN:-100}

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

gen_uuid()   { cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)/\1-\2-\3-\4-/'; }
gen_pass()   { cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1; }
gen_suffix() { cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1; }

START_EPOCH=$(date +%s)

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

NEXT=$(( START_EPOCH + REFRESH_SECS ))

cat > /tmp/status.json << SEOF
{
  "status": "online",
  "uuid": "$UUID",
  "password": "$PASS",
  "suffix": {
    "vless_ws":  "$S1",
    "vless_hu":  "$S2",
    "vmess_ws":  "$S3",
    "vmess_hu":  "$S4",
    "trojan_ws": "$S5",
    "trojan_hu": "$S6",
    "ss_ws":     "$S7",
    "ss_hu":     "$S8"
  },
  "created":      $START_EPOCH,
  "next_refresh": $NEXT,
  "duration":     "$DURATION_RAW",
  "refresh_secs": $REFRESH_SECS
}
SEOF

exec /usr/bin/supervisord -c /etc/supervisord.conf
