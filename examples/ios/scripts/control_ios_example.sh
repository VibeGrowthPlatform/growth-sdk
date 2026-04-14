#!/usr/bin/env bash
set -euo pipefail

# Drives the Vibe Growth native iOS example app through its in-app HTTP
# control server. Defaults target the iOS Simulator.

CONTROL_HOST="${VG_IOS_EXAMPLE_CONTROL_HOST:-127.0.0.1}"
CONTROL_PORT="${VG_IOS_EXAMPLE_CONTROL_PORT:-8766}"
BUNDLE_ID="${VG_IOS_EXAMPLE_BUNDLE_ID:-com.vibegrowth.example.VGExampleApp}"

usage() {
  cat <<'EOF'
Usage:
  control_ios_example.sh open
  control_ios_example.sh initialize [base_url]
  control_ios_example.sh set-user-id [user_id]
  control_ios_example.sh track-purchase [amount] [currency] [product_id]
  control_ios_example.sh track-ad-revenue [source] [revenue] [currency]
  control_ios_example.sh track-session-start [session_start]
  control_ios_example.sh get-config
  control_ios_example.sh refresh
  control_ios_example.sh status
  control_ios_example.sh health
  control_ios_example.sh raw <command> [key=value ...]

Environment:
  VG_IOS_EXAMPLE_CONTROL_HOST  Defaults to 127.0.0.1.
  VG_IOS_EXAMPLE_CONTROL_PORT  Defaults to 8766.
  VG_IOS_EXAMPLE_BUNDLE_ID     Defaults to com.vibegrowth.example.VGExampleApp.

Each command prints the JSON result body from the native iOS example app.
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
    local key="${pair%%=*}"
    local value="${pair#*=}"
    if [[ "$pair" != *"="* ]]; then
      echo "raw args must be key=value pairs, got: $pair" >&2
      exit 1
    fi
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

case "$command_name" in
  open)
    xcrun simctl launch booted "$BUNDLE_ID"
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
    query=""
    if (($# >= 1)) && [[ -n "${1:-}" ]]; then
      query="$(kv_query base_url "$1")"
    fi
    ;;
  set-user-id)
    if (($# == 0)); then
      query=""
    else
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
    if (($# == 0)); then
      query=""
    else
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
  echo "Boot a simulator, build the example app, and launch it first." >&2
  exit 1
fi

url="${base_endpoint}/${command_name}"
if [[ -n "$query" ]]; then
  url="${url}?${query}"
fi

echo "POST ${url}" >&2
curl -fsS -X POST "$url"
echo
