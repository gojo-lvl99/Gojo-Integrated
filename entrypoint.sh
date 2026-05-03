#!/bin/sh

# ─────────────────────────────────────────────
# GOJO I/O — Entrypoint
# ─────────────────────────────────────────────

DURATION_RAW=${DURATION:-"unli"}
MAX_CONN=${MAX_CONN:-100}
MAINTENANCE_SECS=3600

# ── Parse DURATION to seconds ─────────────────
parse_seconds() {
  local raw=$1
  case $raw in
    *h) echo $(( ${raw%h} * 3600 )) ;;
    *d) echo $(( ${raw%d} * 86400 )) ;;
    *m) echo $(( ${raw%m} * 2592000 )) ;;
    "unli"|"") echo 0 ;;
    *) echo 0 ;;
  esac
}

DURATION_SECS=$(parse_seconds "$DURATION_RAW")

# ── Refresh interval ──────────────────────────
# <= 7d (604800s) → 6h refresh
# > 7d or unli   → 5h30m refresh
if [ "$DURATION_SECS" -gt 0 ] && [ "$DURATION_SECS" -le 604800 ]; then
  REFRESH_SECS=21600
else
  REFRESH_SECS=19800
fi

# ── Patch nginx MAX_CONN ──────────────────────
sed -i "s/MAX_CONN_HERE/$MAX_CONN/g" /etc/nginx/nginx.conf

# ── Start nginx via supervisord ───────────────
/usr/bin/supervisord -c /etc/supervisord.conf &
sleep 2

# ── Record start time ─────────────────────────
START_EPOCH=$(date +%s)

# ── Helpers ───────────────────────────────────
gen_uuid() {
  cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | \
    sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)/\1-\2-\3-\4-/'
}

gen_pass() {
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1
}

gen_suffix() {
  cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1
}

write_status() {
  local status=$1
  local uuid=$2
  local pass=$3
  local s1=$4
  local s2=$5
  local s3=$6
  local s4=$7
  local next_refresh=$8

  cat > /tmp/status.json << STATUSEOF
{
  "status": "$status",
  "uuid": "$uuid",
  "password": "$pass",
  "suffix": {
    "vless_ws": "$s1",
    "vless_hu": "$s2",
    "trojan_ws": "$s3",
    "trojan_hu": "$s4"
  },
  "created": $START_EPOCH,
  "next_refresh": $next_refresh,
  "duration": "$DURATION_RAW",
  "refresh_secs": $REFRESH_SECS
}
STATUSEOF
}

# ── Main loop ─────────────────────────────────
CYCLE=0

while true; do
  CYCLE=$(( CYCLE + 1 ))
  NOW=$(date +%s)

  # Check duration expiry
  if [ "$DURATION_SECS" -gt 0 ]; then
    ELAPSED=$(( NOW - START_EPOCH ))
    if [ "$ELAPSED" -ge "$DURATION_SECS" ]; then
      pkill xray 2>/dev/null || true
      echo '{"status":"expired","created":'$START_EPOCH',"duration":"'$DURATION_RAW'"}' > /tmp/status.json
      echo "[GOJO I/O] Duration expired. VPN service stopped."
      # Keep nginx alive — serves expired page
      wait
      exit 0
    fi
  fi

  # Generate fresh credentials
  UUID=$(gen_uuid)
  PASS=$(gen_pass)
  S1=$(gen_suffix)
  S2=$(gen_suffix)
  S3=$(gen_suffix)
  S4=$(gen_suffix)

  # Write xray config from template
  sed \
    -e "s/PLACEHOLDER_UUID/$UUID/g" \
    -e "s/PLACEHOLDER_PASSWORD/$PASS/g" \
    -e "s/PLACEHOLDER_S1/$S1/g" \
    -e "s/PLACEHOLDER_S2/$S2/g" \
    -e "s/PLACEHOLDER_S3/$S3/g" \
    -e "s/PLACEHOLDER_S4/$S4/g" \
    /etc/xray/config.json > /tmp/xray-config.json

  # Kill old xray gracefully
  pkill xray 2>/dev/null || true
  sleep 1

  # Start fresh xray
  xray run -config /tmp/xray-config.json &

  # Calculate next refresh epoch
  NEXT_REFRESH=$(( $(date +%s) + REFRESH_SECS ))

  # Write online status
  write_status "online" "$UUID" "$PASS" "$S1" "$S2" "$S3" "$S4" "$NEXT_REFRESH"

  echo "[GOJO I/O] Cycle $CYCLE online. UUID: $UUID"

  # Wait for refresh interval
  sleep $REFRESH_SECS

  # Enter maintenance mode — xray off, nginx serves maintenance page
  pkill xray 2>/dev/null || true
  MAINT_END=$(( $(date +%s) + MAINTENANCE_SECS ))

  cat > /tmp/status.json << MAINTEOF
{
  "status": "maintenance",
  "created": $START_EPOCH,
  "next_refresh": $MAINT_END,
  "duration": "$DURATION_RAW"
}
MAINTEOF

  echo "[GOJO I/O] Maintenance mode. Resuming in 1 hour..."
  sleep $MAINTENANCE_SECS
done

