#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

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

run_step "Flutter analyze" bash -c "cd '$ROOT/vibegrowth-sdk-flutter' && flutter analyze"
run_step "Flutter test" bash -c "cd '$ROOT/vibegrowth-sdk-flutter' && flutter test"

run_step "Native Android build" bash -c '
  cd "'"$ROOT"'/vibegrowth-sdk-native/android"
  if command -v /usr/libexec/java_home >/dev/null 2>&1; then
    export JAVA_HOME=$(/usr/libexec/java_home -v 17)
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  ./gradlew test build
'

if [[ "$(uname -s)" == "Darwin" ]] && command -v xcodebuild >/dev/null 2>&1; then
    run_step "Native iOS build" bash -c "cd '$ROOT/vibegrowth-sdk-native/ios' && xcodebuild -scheme VibeGrowthSDK -destination 'generic/platform=iOS' build"
    run_step "Native iOS tests" bash -c "cd '$ROOT/vibegrowth-sdk-native/ios' && xcodebuild -scheme VibeGrowthSDK -destination 'platform=iOS Simulator,name=iPhone 16' test"
else
    bold "→ Native iOS build"
    echo "  skipped (requires macOS + Xcode)"
    echo
fi

run_step "Vendored source sync" bash -c "
  diff -rq '$ROOT/vibegrowth-sdk-native/android/src/main/kotlin/com/vibegrowth/sdk' '$ROOT/vibegrowth-sdk-unity/Plugins/Android/src/main/kotlin/com/vibegrowth/sdk' &&
  diff -rq '$ROOT/vibegrowth-sdk-native/ios/Sources/VibeGrowthSDK' '$ROOT/vibegrowth-sdk-unity/Plugins/iOS/Sources' &&
  diff -rq '$ROOT/vibegrowth-sdk-native/android/src/main/kotlin/com/vibegrowth/sdk' '$ROOT/vibegrowth-sdk-flutter/android/src/main/kotlin/com/vibegrowth/sdk' --exclude flutter &&
  diff -rq '$ROOT/vibegrowth-sdk-native/ios/Sources/VibeGrowthSDK' '$ROOT/vibegrowth-sdk-flutter/ios/Classes' --exclude VibeGrowthSdkPlugin.swift
"

if [[ $FAILED -eq 0 ]]; then
    green "=== All SDK checks passed ==="
else
    red "=== $FAILED SDK check(s) FAILED ==="
    exit 1
fi
