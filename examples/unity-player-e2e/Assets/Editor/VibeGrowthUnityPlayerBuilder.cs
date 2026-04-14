using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class VibeGrowthUnityPlayerBuilder
{
    public static void BuildMacOS()
    {
        var outputPath = Environment.GetEnvironmentVariable("VG_UNITY_PLAYER_BUILD_PATH");
        if (string.IsNullOrWhiteSpace(outputPath))
        {
            outputPath = Path.GetFullPath("Builds/VibeGrowthUnityE2E.app");
        }

        Directory.CreateDirectory("Assets/Generated");
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        var go = new GameObject("Vibe Growth Player E2E");
        go.AddComponent<VibeGrowthPlayerE2EController>();
        var scenePath = "Assets/Generated/PlayerE2E.unity";
        EditorSceneManager.SaveScene(scene, scenePath);

        var report = BuildPipeline.BuildPlayer(
            new BuildPlayerOptions
            {
                scenes = new[] { scenePath },
                locationPathName = outputPath,
                target = BuildTarget.StandaloneOSX,
                options = BuildOptions.None,
            }
        );

        if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
        {
            throw new InvalidOperationException($"Unity player build failed: {report.summary.result}");
        }

        Debug.Log($"[VibeGrowthUnityPlayerBuilder] built {outputPath}");
    }
}
