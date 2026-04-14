#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_EXAMPLE_DIR="$ROOT/vibegrowth-sdk-native/examples/android"
CONTROL_SCRIPT="$ANDROID_EXAMPLE_DIR/scripts/control_android_example.sh"

APP_ID="${VIBEGROWTH_SDK_E2E_APP_ID:-sm_app_sdk_e2e}"
API_KEY="${VIBEGROWTH_SDK_E2E_API_KEY:-sk_live_sdk_e2e_local_only}"
HOST_BASE_URL="${VIBEGROWTH_SDK_E2E_HOST_BASE_URL:-http://localhost:8000}"
ANDROID_BASE_URL="${VG_ANDROID_EXAMPLE_BASE_URL:-http://10.0.2.2:8000}"
CLICKHOUSE_URL="${VIBEGROWTH_SDK_E2E_CLICKHOUSE_URL:-http://localhost:8123}"
CLICKHOUSE_DB="${VIBEGROWTH_SDK_E2E_CLICKHOUSE_DATABASE:-scalemonk}"
CONTROL_PORT="${VG_ANDROID_EXAMPLE_CONTROL_PORT:-8766}"
ADB="${ADB:-adb}"

PREPARE_BACKEND=true
INSTALL_APP=true

for arg in "$@"; do
  case "$arg" in
    --skip-backend)
      PREPARE_BACKEND=false
      ;;
    --skip-install)
      INSTALL_APP=false
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

wait_for_backend_ready() {
  for _ in $(seq 1 60); do
    if curl -fsS "$HOST_BASE_URL/api/readyz" >/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 1
}

wait_for_control_server() {
  for _ in $(seq 1 40); do
    if curl -fsS "http://127.0.0.1:${CONTROL_PORT}/health" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_android_boot() {
  for _ in $(seq 1 120); do
    if [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

ch_query() {
  local query="$1"
  curl -fsS "${CLICKHOUSE_URL}/?database=${CLICKHOUSE_DB}&wait_end_of_query=1" \
    --data-binary "$query"
}

eventually_equals() {
  local expected="$1"
  local query="$2"
  local label="$3"
  local value=""
  local last_error=""

  for _ in $(seq 1 60); do
    if value="$(ch_query "$query" 2>/tmp/vg-android-example-ch-error.log)"; then
      value="$(printf '%s' "$value" | tr -d '\r' | sed -e 's/[[:space:]]*$//')"
      if [[ "$value" == "$expected" ]]; then
        green "  ✓ $label = $expected" >&2
        return 0
      fi
    else
      last_error="$(cat /tmp/vg-android-example-ch-error.log 2>/dev/null || true)"
    fi
    sleep 1
  done

  echo "Timed out waiting for $label" >&2
  echo "Expected: $expected" >&2
  echo "Last value: $value" >&2
  if [[ -n "$last_error" ]]; then
    echo "Last ClickHouse error: $last_error" >&2
  fi
  echo "Query:" >&2
  echo "$query" >&2
  exit 1
}

eventually_nonempty() {
  local query="$1"
  local label="$2"
  local value=""

  for _ in $(seq 1 60); do
    value="$(ch_query "$query" | tr -d '\r' | sed -e 's/[[:space:]]*$//')"
    if [[ -n "$value" ]]; then
      green "  ✓ $label = $value" >&2
      printf '%s' "$value"
      return 0
    fi
    sleep 1
  done

  echo "Timed out waiting for $label" >&2
  echo "Query:" >&2
  echo "$query" >&2
  exit 1
}

sql_string() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\'}"
}

run_control() {
  "$CONTROL_SCRIPT" "$@"
}

require_cmd curl
require_cmd "$ADB"

if $PREPARE_BACKEND; then
  require_cmd docker
  bold "→ Android example e2e backend stack"
  docker compose up -d --build postgres clickhouse redis backend
  wait_for_backend_ready
  docker compose exec -T backend python -m app.forge.scripts.seed_sdk_e2e_app
  docker compose exec -T backend python -m app.release_tasks
  CLICKHOUSE_DB="$(docker compose exec -T backend python -c 'from app.config import settings; print(settings.clickhouse_database)' | tr -d '\r')"
  green "  ✓ backend ready, seeded app_id=$APP_ID, clickhouse_db=$CLICKHOUSE_DB"
fi

bold "→ Android device"
DEVICE_STATE=""
for _ in $(seq 1 20); do
  if DEVICE_STATE="$("$ADB" get-state 2>/dev/null)"; then
    break
  fi
  sleep 1
done
if [[ "$DEVICE_STATE" != "device" ]]; then
  echo "No Android emulator/device is available. Start one, then rerun this script." >&2
  exit 1
fi
wait_for_android_boot
green "  ✓ $DEVICE_STATE"

if $INSTALL_APP; then
  bold "→ Native Android example install"
  if command -v /usr/libexec/java_home >/dev/null 2>&1; then
    export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  (cd "$ANDROID_EXAMPLE_DIR" && ./gradlew --no-daemon :app:installDebug)
  green "  ✓ installed debug example app"
fi

bold "→ Native Android example launch"
"$ADB" shell pm clear com.vibegrowth.example >/dev/null
"$ADB" forward "tcp:${CONTROL_PORT}" "tcp:${CONTROL_PORT}" >/dev/null
"$ADB" shell am start -n com.vibegrowth.example/.MainActivity >/dev/null
wait_for_control_server
green "  ✓ control server reachable at http://127.0.0.1:${CONTROL_PORT}"

RUN_ID="$(date +%s)-$RANDOM"
USER_ID="android-example-user-$RUN_ID"
PRODUCT_ID="android-example-product-$RUN_ID"
SESSION_START="2026-04-10T10:00:00+00:00"

bold "→ Drive Android example app through native SDK"
run_control initialize "$ANDROID_BASE_URL" "$APP_ID" "$API_KEY"
run_control set-user-id "$USER_ID"
run_control track-purchase 4.99 USD "$PRODUCT_ID"
run_control track-ad-revenue admob 0.02 USD
run_control track-session-start "$SESSION_START"
run_control get-config

bold "→ Verify backend persistence in ClickHouse"
DEVICE_ID="$(eventually_nonempty "
SELECT device_id
FROM devices FINAL
WHERE user_id = $(sql_string "$USER_ID")
ORDER BY updated_at DESC
LIMIT 1
FORMAT TSVRaw
" "device_id for $USER_ID")"

eventually_equals "$USER_ID" "
SELECT ifNull(user_id, '')
FROM devices FINAL
WHERE device_id = $(sql_string "$DEVICE_ID")
ORDER BY updated_at DESC
LIMIT 1
FORMAT TSVRaw
" "identified device user_id"

eventually_equals "android" "
SELECT platform
FROM devices
WHERE device_id = $(sql_string "$DEVICE_ID")
  AND platform = 'android'
ORDER BY updated_at ASC
LIMIT 1
FORMAT TSVRaw
" "init device platform row"

eventually_equals "$PRODUCT_ID" "
SELECT ifNull(product_id, '')
FROM revenue_events
WHERE device_id = $(sql_string "$DEVICE_ID")
  AND product_id = $(sql_string "$PRODUCT_ID")
ORDER BY received_at DESC
LIMIT 1
FORMAT TSVRaw
" "purchase product_id"

eventually_equals "ad_revenue" "
SELECT revenue_type
FROM revenue_events
WHERE device_id = $(sql_string "$DEVICE_ID")
  AND revenue_type = 'ad_revenue'
ORDER BY received_at DESC
LIMIT 1
FORMAT TSVRaw
" "ad revenue event"

eventually_equals "1" "
SELECT toString(count())
FROM session_events
WHERE device_id = $(sql_string "$DEVICE_ID")
  AND user_id = $(sql_string "$USER_ID")
  AND session_start = parseDateTime64BestEffort($(sql_string "$SESSION_START"))
FORMAT TSVRaw
" "session event count"

bold "→ Android example e2e evidence"
cat <<EOF
app_id=$APP_ID
android_base_url=$ANDROID_BASE_URL
backend_ready_url=$HOST_BASE_URL/api/readyz
clickhouse_url=$CLICKHOUSE_URL
clickhouse_database=$CLICKHOUSE_DB
control_url=http://127.0.0.1:${CONTROL_PORT}
user_id=$USER_ID
product_id=$PRODUCT_ID
device_id=$DEVICE_ID
verified_tables=devices,revenue_events,session_events
EOF

green "=== Native Android example real-backend e2e passed ==="
