#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
RUN_E2E=false
SDK_E2E_READY=false

SDK_E2E_APP_ID="sm_app_sdk_e2e"
SDK_E2E_API_KEY="sk_live_sdk_e2e_local_only"
SDK_E2E_BASE_URL="${VIBEGROWTH_SDK_E2E_BASE_URL:-http://127.0.0.1:8000}"
SDK_E2E_CLICKHOUSE_URL="${VIBEGROWTH_SDK_E2E_CLICKHOUSE_URL:-http://127.0.0.1:8123}"
SDK_E2E_CLICKHOUSE_DATABASE="${VIBEGROWTH_SDK_E2E_CLICKHOUSE_DATABASE:-scalemonk}"
SDK_E2E_CONFIG_FILE="/tmp/vibegrowth-sdk-e2e.json"

for arg in "$@"; do
  case "$arg" in
    --e2e)
      RUN_E2E=true
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

run_step() {
    local label="$1"
    shift
    bold "→ $label"
    if "$@"; then
        green "  ✓ $label passed"
    else
        red "  ✗ $label FAILED"
        FAILED=$((FAILED + 1))
    fi
    echo
}

wait_for_backend_ready() {
    local attempts=60
    local delay_seconds=2

    for ((i=1; i<=attempts; i++)); do
        if curl -fsS "$SDK_E2E_BASE_URL/api/readyz" >/dev/null; then
            return 0
        fi
        sleep "$delay_seconds"
    done

    return 1
}

write_sdk_e2e_config() {
    python3 - "$SDK_E2E_CONFIG_FILE" "$SDK_E2E_APP_ID" "$SDK_E2E_API_KEY" "$SDK_E2E_BASE_URL" "$SDK_E2E_CLICKHOUSE_URL" "$SDK_E2E_CLICKHOUSE_DATABASE" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(
    json.dumps(
        {
            "enabled": True,
            "appId": sys.argv[2],
            "apiKey": sys.argv[3],
            "baseUrl": sys.argv[4],
            "clickHouseUrl": sys.argv[5],
            "clickHouseDatabase": sys.argv[6],
        }
    ),
    encoding="utf-8",
)
PY
}

prepare_sdk_e2e_env() {
    bold "→ SDK e2e backend ready"
    if wait_for_backend_ready; then
        green "  ✓ SDK e2e backend ready passed"
    else
        red "  ✗ SDK e2e backend ready FAILED"
        red "    Start the Vibe Growth backend locally (see the backend repo's 'make dev')"
        red "    and seed the SDK e2e app before rerunning with --e2e."
        FAILED=$((FAILED + 1))
        echo
        return 1
    fi
    echo

    export VIBEGROWTH_SDK_E2E=1
    export VIBEGROWTH_SDK_E2E_APP_ID="$SDK_E2E_APP_ID"
    export VIBEGROWTH_SDK_E2E_API_KEY="$SDK_E2E_API_KEY"
    export VIBEGROWTH_SDK_E2E_BASE_URL="$SDK_E2E_BASE_URL"
    export VIBEGROWTH_SDK_E2E_CLICKHOUSE_URL="$SDK_E2E_CLICKHOUSE_URL"
    export VIBEGROWTH_SDK_E2E_CLICKHOUSE_DATABASE="$SDK_E2E_CLICKHOUSE_DATABASE"
    export VIBEGROWTH_SDK_E2E_CONFIG_FILE="$SDK_E2E_CONFIG_FILE"
    if write_sdk_e2e_config; then
        SDK_E2E_READY=true
        return 0
    fi

    red "  ✗ SDK e2e config file FAILED"
    FAILED=$((FAILED + 1))
    echo
    return 1
}

if $RUN_E2E; then
    prepare_sdk_e2e_env || true
fi

run_step "Flutter analyze" bash -c "cd '$ROOT/flutter' && flutter analyze"
run_step "Flutter test" bash -c "cd '$ROOT/flutter' && flutter test"

run_step "Native Android build" bash -c '
  cd "'"$ROOT"'/android"
  if command -v /usr/libexec/java_home >/dev/null 2>&1; then
    export JAVA_HOME=$(/usr/libexec/java_home -v 17)
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  ./gradlew --no-daemon clean test build
'

if [[ "$(uname -s)" == "Darwin" ]] && command -v xcodebuild >/dev/null 2>&1; then
    run_step "Native iOS build" bash -c "cd '$ROOT/ios' && xcodebuild -scheme VibeGrowthSDK -destination 'generic/platform=iOS' build"
    run_step "Native iOS tests" bash -c "cd '$ROOT/ios' && xcodebuild -scheme VibeGrowthSDK -destination 'platform=iOS Simulator,name=iPhone 16' test"
    run_step "Native iOS example project" bash -c "cd '$ROOT/examples/ios' && rm -rf VGExampleApp.xcodeproj && xcodegen generate"
    run_step "Native iOS example build" bash -c "cd '$ROOT/examples/ios' && xcodebuild -project VGExampleApp.xcodeproj -scheme VGExampleApp -destination 'platform=iOS Simulator,name=iPhone 16' build"
    run_step "Native iOS example e2e tests" bash -c "cd '$ROOT/examples/ios' && xcodebuild -project VGExampleApp.xcodeproj -scheme VGExampleApp -destination 'platform=iOS Simulator,name=iPhone 16' test"
else
    bold "→ Native iOS build"
    echo "  skipped (requires macOS + Xcode)"
    echo
fi

if $RUN_E2E; then
    run_step "Unity player app e2e" bash -c "cd '$ROOT' && examples/unity-player-e2e/scripts/run_player_e2e.sh"
fi

run_step "Vendored source sync" bash -c "
  diff -rq --exclude '*.meta' '$ROOT/android/src/main/kotlin/com/vibegrowth/sdk' '$ROOT/unity/Plugins/Android/src/main/kotlin/com/vibegrowth/sdk' &&
  diff -rq --exclude '*.meta' '$ROOT/ios/Sources/VibeGrowthSDK' '$ROOT/unity/Plugins/iOS/Sources' &&
  diff -rq '$ROOT/android/src/main/kotlin/com/vibegrowth/sdk' '$ROOT/flutter/android/src/main/kotlin/com/vibegrowth/sdk' --exclude flutter &&
  diff -rq '$ROOT/ios/Sources/VibeGrowthSDK' '$ROOT/flutter/ios/Classes' --exclude VibeGrowthSdkPlugin.swift
"

if $RUN_E2E && ! $SDK_E2E_READY; then
    red "=== SDK e2e environment could not be prepared ==="
    exit 1
fi

if [[ $FAILED -eq 0 ]]; then
    if $RUN_E2E; then
        green "=== All SDK checks passed (including real-backend e2e) ==="
    else
        green "=== All SDK checks passed ==="
    fi
else
    red "=== $FAILED SDK check(s) FAILED ==="
    exit 1
fi
