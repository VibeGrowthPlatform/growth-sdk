#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PROJECT_PATH="$ROOT/vibegrowth-sdk-unity/Examples~/UnityPlayerE2E"
BUILD_PATH="$PROJECT_PATH/Builds/VibeGrowthUnityE2E.app"
RESULTS_PATH="$PROJECT_PATH/PlayerE2EResults.xml"
BUILD_LOG_PATH="$PROJECT_PATH/unity-player-build.log"
PLAYER_LOG_PATH="$PROJECT_PATH/unity-player-e2e.log"

find_unity() {
    if [[ -n "${UNITY_EXECUTABLE:-}" ]]; then
        printf '%s\n' "$UNITY_EXECUTABLE"
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
    echo "Unity executable not found. Set UNITY_EXECUTABLE to run Unity SDK player E2E validation." >&2
    exit 1
fi

rm -rf "$BUILD_PATH" "$RESULTS_PATH" "$BUILD_LOG_PATH" "$PLAYER_LOG_PATH"
export VG_UNITY_PLAYER_BUILD_PATH="$BUILD_PATH"

"$UNITY_BIN" \
    -batchmode \
    -nographics \
    -quit \
    -projectPath "$PROJECT_PATH" \
    -executeMethod VibeGrowthUnityPlayerBuilder.BuildMacOS \
    -logFile "$BUILD_LOG_PATH"

PLAYER_BIN="$(find "$BUILD_PATH/Contents/MacOS" -type f -perm +111 | head -1)"
if [[ -z "$PLAYER_BIN" ]]; then
    echo "Could not find built Unity player executable under $BUILD_PATH/Contents/MacOS" >&2
    exit 1
fi

export VG_UNITY_PLAYER_E2E=1
export VG_UNITY_PLAYER_E2E_RESULTS_PATH="$RESULTS_PATH"

"$PLAYER_BIN" -batchmode -nographics -logFile "$PLAYER_LOG_PATH"

if [[ ! -f "$RESULTS_PATH" ]]; then
    echo "Unity player did not produce $RESULTS_PATH. See $PLAYER_LOG_PATH." >&2
    exit 1
fi

if grep -q 'result="Failed"' "$RESULTS_PATH"; then
    echo "Unity player E2E failed. See $RESULTS_PATH and $PLAYER_LOG_PATH." >&2
    exit 1
fi

echo "Unity player E2E passed: $RESULTS_PATH"
