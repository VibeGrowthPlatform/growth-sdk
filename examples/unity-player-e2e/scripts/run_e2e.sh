#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_PATH="$PROJECT_PATH/TestResults.xml"
LOG_PATH="$PROJECT_PATH/unity-e2e.log"

find_unity() {
    if [[ -n "${UNITY_EXECUTABLE:-}" ]]; then
        printf '%s\n' "$UNITY_EXECUTABLE"
        return 0
    fi

    if command -v Unity >/dev/null 2>&1; then
        command -v Unity
        return 0
    fi

    if command -v unity >/dev/null 2>&1; then
        command -v unity
        return 0
    fi

    local project_version
    project_version="$(awk '/^m_EditorVersion:/ { print $2; exit }' "$PROJECT_PATH/ProjectSettings/ProjectVersion.txt" 2>/dev/null || true)"
    if [[ -n "$project_version" ]]; then
        local versioned_candidate="/Applications/Unity/Hub/Editor/$project_version/Unity.app/Contents/MacOS/Unity"
        if [[ -x "$versioned_candidate" ]]; then
            printf '%s\n' "$versioned_candidate"
            return 0
        fi
    fi

    local candidate
    candidate="$(ls -d /Applications/Unity/Hub/Editor/*/Unity.app/Contents/MacOS/Unity 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    return 1
}

UNITY_BIN="$(find_unity || true)"
if [[ -z "$UNITY_BIN" ]]; then
    echo "Unity executable not found. Set UNITY_EXECUTABLE to run Unity SDK E2E validation." >&2
    exit 1
fi

rm -f "$RESULTS_PATH" "$LOG_PATH"
export VG_UNITY_E2E_RESULTS_PATH="$RESULTS_PATH"

"$UNITY_BIN" \
    -batchmode \
    -nographics \
    -quit \
    -projectPath "$PROJECT_PATH" \
    -executeMethod VibeGrowthUnityE2ERunner.Run \
    -logFile "$LOG_PATH"

if [[ ! -f "$RESULTS_PATH" ]]; then
    echo "Unity did not produce $RESULTS_PATH. See $LOG_PATH." >&2
    exit 1
fi

if grep -q 'result="Failed"' "$RESULTS_PATH"; then
    echo "Unity E2E tests failed. See $RESULTS_PATH and $LOG_PATH." >&2
    exit 1
fi

echo "Unity E2E tests passed: $RESULTS_PATH"
