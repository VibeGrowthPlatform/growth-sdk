#!/usr/bin/env bash
set -euo pipefail

# Drives the native Android example app through its in-app HTTP control server.
# For an emulator or USB device, run `forward` first so the host can reach the
# app at http://127.0.0.1:8766.

CONTROL_HOST="${VG_ANDROID_EXAMPLE_CONTROL_HOST:-127.0.0.1}"
CONTROL_PORT="${VG_ANDROID_EXAMPLE_CONTROL_PORT:-8766}"
PACKAGE_NAME="${VG_ANDROID_EXAMPLE_PACKAGE:-com.vibegrowth.example}"
ACTIVITY_NAME="${VG_ANDROID_EXAMPLE_ACTIVITY:-com.vibegrowth.example/.MainActivity}"
ADB="${ADB:-adb}"

usage() {
  cat <<'EOF'
Usage:
  control_android_example.sh forward
  control_android_example.sh open
  control_android_example.sh clear
  control_android_example.sh health
  control_android_example.sh status
  control_android_example.sh initialize [base_url] [app_id] [api_key]
  control_android_example.sh set-user-id [user_id]
  control_android_example.sh track-purchase [amount] [currency] [product_id]
  control_android_example.sh track-ad-revenue [source] [revenue] [currency]
  control_android_example.sh track-session-start [session_start]
  control_android_example.sh get-config
  control_android_example.sh refresh
  control_android_example.sh raw <command> [key=value ...]

Environment:
  VG_ANDROID_EXAMPLE_CONTROL_HOST  Defaults to 127.0.0.1.
  VG_ANDROID_EXAMPLE_CONTROL_PORT  Defaults to 8766.
  VG_ANDROID_EXAMPLE_PACKAGE       Defaults to com.vibegrowth.example.
  VG_ANDROID_EXAMPLE_ACTIVITY      Defaults to com.vibegrowth.example/.MainActivity.
  ADB                              Defaults to adb.

For local backend testing from an Android emulator, use base_url
http://10.0.2.2:8000.
EOF
}

urlencode() {
  /usr/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

build_query() {
  local query=""
  while (($# >= 1)); do
    local pair="$1"
    shift
    if [[ "$pair" != *"="* ]]; then
      echo "raw args must be key=value pairs, got: $pair" >&2
      exit 1
    fi
    local key="${pair%%=*}"
    local value="${pair#*=}"
    query+="${query:+&}$(urlencode "$key")=$(urlencode "$value")"
  done
  printf '%s' "$query"
}

kv_query() {
  local query=""
  while (($# >= 2)); do
    local key="$1"
    local value="$2"
    shift 2
    query+="${query:+&}$(urlencode "$key")=$(urlencode "$value")"
  done
  printf '%s' "$query"
}

if (($# == 0)); then
  usage
  exit 1
fi

command_name="$1"
shift
base_endpoint="http://${CONTROL_HOST}:${CONTROL_PORT}"
query=""

case "$command_name" in
  forward)
    "$ADB" forward "tcp:${CONTROL_PORT}" "tcp:${CONTROL_PORT}"
    exit $?
    ;;
  open)
    "$ADB" shell am start -n "$ACTIVITY_NAME"
    exit $?
    ;;
  clear)
    "$ADB" shell pm clear "$PACKAGE_NAME"
    exit $?
    ;;
  health)
    curl -fsS "${base_endpoint}/health"
    echo
    exit 0
    ;;
  status)
    curl -fsS "${base_endpoint}/status"
    echo
    exit 0
    ;;
  initialize)
    query="$(kv_query base_url "${1:-http://10.0.2.2:8000}" app_id "${2:-sm_app_sdk_e2e}" api_key "${3:-sk_live_sdk_e2e_local_only}")"
    ;;
  set-user-id)
    if (($# > 0)); then
      query="$(kv_query user_id "$1")"
    fi
    ;;
  track-purchase)
    query="$(kv_query amount "${1:-4.99}" currency "${2:-USD}" product_id "${3:-gem_pack_100}")"
    ;;
  track-ad-revenue)
    query="$(kv_query source "${1:-admob}" revenue "${2:-0.02}" currency "${3:-USD}")"
    ;;
  track-session-start)
    if (($# > 0)); then
      query="$(kv_query session_start "$1")"
    fi
    ;;
  get-config|refresh)
    query=""
    ;;
  raw)
    if (($# == 0)); then
      usage
      exit 1
    fi
    command_name="$1"
    shift
    query="$(build_query "$@")"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if ! curl -fsS "${base_endpoint}/health" >/dev/null 2>&1; then
  echo "Control server is not reachable at ${base_endpoint}/health" >&2
  echo "Install and open the native Android example, then run:" >&2
  echo "  $0 forward" >&2
  exit 1
fi

url="${base_endpoint}/${command_name}"
if [[ -n "$query" ]]; then
  url="${url}?${query}"
fi

echo "POST ${url}" >&2
curl -fsS -X POST "$url"
echo
