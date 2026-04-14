using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using UnityEngine;
using VibeGrowth;

public sealed class VibeGrowthExampleController : MonoBehaviour
{
    private const string ConfigPath = "/tmp/vibegrowth-sdk-e2e.json";

    private SdkE2eConfig _config;
    private string _status = "idle";
    private string _userId;
    private readonly List<string> _logs = new List<string>();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void Bootstrap()
    {
        if (Environment.GetEnvironmentVariable("VG_UNITY_PLAYER_E2E") == "1")
        {
            return;
        }

        if (FindObjectOfType<VibeGrowthExampleController>() != null)
        {
            return;
        }

        var go = new GameObject("Vibe Growth Example");
        DontDestroyOnLoad(go);
        go.AddComponent<VibeGrowthExampleController>();
    }

    private void Start()
    {
        _config = SdkE2eConfig.Load();
        _userId = $"unity-example-user-{Guid.NewGuid()}";
        Log($"Loaded baseUrl={_config.BaseUrl}");

        Initialize();

        if (Environment.GetEnvironmentVariable("VG_UNITY_EXAMPLE_AUTO_RUN") == "1")
        {
            StartCoroutine(AutoRun());
        }
    }

    private IEnumerator AutoRun()
    {
        yield return new WaitUntil(() => _status == "initialized" || _status.StartsWith("init failed", StringComparison.Ordinal));
        if (_status != "initialized")
        {
            yield break;
        }

        SetUserId();
        yield return new WaitForSeconds(0.25f);
        TrackPurchase();
        TrackAdRevenue();
        TrackSessionStart("2026-04-02T10:00:00+00:00");
        TrackSessionStart("2026-04-02T10:05:00+00:00");
        GetConfig();
    }

    private void OnGUI()
    {
        GUILayout.BeginArea(new Rect(24, 24, 520, 520));
        GUILayout.Label("Vibe Growth Unity Example");
        GUILayout.Label($"Status: {_status}");
        GUILayout.Label($"Base URL: {_config.BaseUrl}");
        GUILayout.Label($"User ID: {_userId}");

        if (GUILayout.Button("Initialize SDK"))
        {
            Initialize();
        }
        if (GUILayout.Button("Set User ID"))
        {
            SetUserId();
        }
        if (GUILayout.Button("Track Purchase"))
        {
            TrackPurchase();
        }
        if (GUILayout.Button("Track Ad Revenue"))
        {
            TrackAdRevenue();
        }
        if (GUILayout.Button("Track Session Start"))
        {
            TrackSessionStart(DateTimeOffset.UtcNow.ToString("o"));
        }
        if (GUILayout.Button("Get Config"))
        {
            GetConfig();
        }

        GUILayout.Space(16);
        foreach (var line in _logs)
        {
            GUILayout.Label(line);
        }
        GUILayout.EndArea();
    }

    private void Initialize()
    {
        _status = "initializing";
        VibeGrowthSDK.Initialize(
            _config.AppId,
            _config.ApiKey,
            onSuccess: () =>
            {
                _status = "initialized";
                Log("initialize ok");
            },
            onError: error =>
            {
                _status = $"init failed: {error}";
                Log(_status);
            },
            baseUrl: _config.BaseUrl
        );
    }

    private void SetUserId()
    {
        VibeGrowthSDK.SetUserId(_userId);
        Log($"set user id {_userId}");
    }

    private void TrackPurchase()
    {
        VibeGrowthSDK.TrackPurchase(new Dictionary<string, object>
        {
            { "pricePaid", 4.99 },
            { "currency", "USD" },
            { "productId", "unity_gem_pack_100" },
        });
        Log("track purchase 4.99 USD unity_gem_pack_100");
    }

    private void TrackAdRevenue()
    {
        VibeGrowthSDK.TrackAdRevenue(new Dictionary<string, object>
        {
            { "source", "admob" },
            { "revenue", 0.02 },
            { "currency", "USD" },
        });
        Log("track ad revenue 0.02 USD admob");
    }

    private void TrackSessionStart(string sessionStart)
    {
        VibeGrowthSDK.TrackSessionStart(sessionStart);
        Log($"track session {sessionStart}");
    }

    private void GetConfig()
    {
        VibeGrowthSDK.GetConfig(
            configJson => Log($"config {configJson}"),
            error => Log($"config error {error}")
        );
    }

    private void Log(string message)
    {
        _logs.Insert(0, $"{DateTimeOffset.Now:HH:mm:ss} {message}");
        if (_logs.Count > 12)
        {
            _logs.RemoveAt(_logs.Count - 1);
        }
        Debug.Log($"[VibeGrowthExample] {message}");
    }

    private sealed class SdkE2eConfig
    {
        public string AppId { get; private set; } = "sm_app_sdk_e2e";
        public string ApiKey { get; private set; } = "sk_live_sdk_e2e_local_only";
        public string BaseUrl { get; private set; } = "http://[::1]:8000";

        public static SdkE2eConfig Load()
        {
            var config = new SdkE2eConfig();
            if (!File.Exists(ConfigPath))
            {
                return config;
            }

            var json = File.ReadAllText(ConfigPath);
            config.AppId = StringField(json, "appId") ?? config.AppId;
            config.ApiKey = StringField(json, "apiKey") ?? config.ApiKey;
            config.BaseUrl = NormalizeLoopback(StringField(json, "baseUrl") ?? config.BaseUrl);
            return config;
        }

        private static string NormalizeLoopback(string value)
        {
            return value.Replace("[::1]", "127.0.0.1");
        }

        private static string StringField(string json, string name)
        {
            var match = Regex.Match(json, $"\"{Regex.Escape(name)}\"\\s*:\\s*\"([^\"]*)\"");
            return match.Success ? match.Groups[1].Value : null;
        }
    }
}
