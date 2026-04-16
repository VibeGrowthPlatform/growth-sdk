using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using UnityEngine;
using VibeGrowth;

public sealed class VibeGrowthPlayerE2EController : MonoBehaviour
{
    private const string ConfigPath = "/tmp/vibegrowth-sdk-e2e.json";
    private const string DeviceIdKey = "vibegrowth_device_id";
    private const string UserIdKey = "vibegrowth_user_id";
    private const string HasTrackedFirstSessionKey = "vibegrowth_has_tracked_first_session";

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void Bootstrap()
    {
        if (Environment.GetEnvironmentVariable("VG_UNITY_PLAYER_E2E") != "1")
        {
            return;
        }

        if (FindObjectOfType<VibeGrowthPlayerE2EController>() != null)
        {
            return;
        }

        var go = new GameObject("Vibe Growth Player E2E");
        DontDestroyOnLoad(go);
        go.AddComponent<VibeGrowthPlayerE2EController>();
    }

    private void Start()
    {
        if (Environment.GetEnvironmentVariable("VG_UNITY_PLAYER_E2E") != "1")
        {
            return;
        }

        try
        {
            RunOrThrow();
            WriteResults("Passed", null);
            Debug.Log("[VibeGrowthPlayerE2E] passed");
            Application.Quit(0);
        }
        catch (Exception error)
        {
            WriteResults("Failed", error.ToString());
            Debug.LogError($"[VibeGrowthPlayerE2E] failed: {error}");
            Application.Quit(1);
        }
    }

    private static void RunOrThrow()
    {
        var config = SdkE2eConfig.Load();
        if (!config.Enabled)
        {
            throw new InvalidOperationException("SDK real-backend e2e is disabled");
        }

        ResetSdkForTests();

        var deviceId = $"unity-player-e2e-{Guid.NewGuid()}";
        var userId = $"user-{Guid.NewGuid()}";
        var productId = $"product-{Guid.NewGuid()}";
        var firstSessionStart = "2026-04-02T10:00:00+00:00";
        var secondSessionStart = "2026-04-02T10:05:00+00:00";

        PlayerPrefs.SetString(DeviceIdKey, deviceId);
        PlayerPrefs.DeleteKey(UserIdKey);
        PlayerPrefs.DeleteKey(HasTrackedFirstSessionKey);
        PlayerPrefs.Save();

        Debug.Log($"[VibeGrowthPlayerE2E] initializing deviceId={deviceId}");
        using var initDone = new ManualResetEventSlim(false);
        string initError = null;
        VibeGrowthSDK.Initialize(
            config.AppId,
            config.ApiKey,
            onSuccess: () => initDone.Set(),
            onError: error =>
            {
                initError = error;
                initDone.Set();
            },
            baseUrl: config.BaseUrl
        );

        WaitForSignal("SDK initialization", initDone, TimeSpan.FromSeconds(20));
        if (!string.IsNullOrEmpty(initError))
        {
            throw new InvalidOperationException($"Init failed: {initError}");
        }

        EventuallyEquals(config, "unity", $@"
            SELECT platform
            FROM devices FINAL
            WHERE device_id = {SqlString(deviceId)}
            ORDER BY updated_at DESC
            LIMIT 1
            FORMAT TSVRaw
        ");
        EventuallyEquals(config, "0.0.1", $@"
            SELECT sdk_version
            FROM devices FINAL
            WHERE device_id = {SqlString(deviceId)}
            ORDER BY updated_at DESC
            LIMIT 1
            FORMAT TSVRaw
        ");

        VibeGrowthSDK.SetUserId(userId);
        if (VibeGrowthSDK.GetUserId() != userId)
        {
            throw new InvalidOperationException("SDK user id was not persisted locally");
        }
        EventuallyEquals(config, userId, $@"
            SELECT ifNull(user_id, '')
            FROM devices FINAL
            WHERE device_id = {SqlString(deviceId)}
            ORDER BY updated_at DESC
            LIMIT 1
            FORMAT TSVRaw
        ");

        VibeGrowthSDK.TrackPurchase(new Dictionary<string, object>
        {
            { "pricePaid", 4.99 },
            { "currency", "USD" },
            { "productId", productId },
        });
        EventuallyEquals(config, productId, $@"
            SELECT ifNull(product_id, '')
            FROM revenue_events
            WHERE device_id = {SqlString(deviceId)}
              AND product_id = {SqlString(productId)}
            ORDER BY received_at DESC
            LIMIT 1
            FORMAT TSVRaw
        ");

        VibeGrowthSDK.TrackAdRevenue(new Dictionary<string, object>
        {
            { "source", "admob" },
            { "revenue", 0.02 },
            { "currency", "USD" },
        });
        EventuallyEquals(config, "ad_revenue", $@"
            SELECT revenue_type
            FROM revenue_events
            WHERE device_id = {SqlString(deviceId)}
              AND ad_source = 'admob'
            ORDER BY received_at DESC
            LIMIT 1
            FORMAT TSVRaw
        ");

        VibeGrowthSDK.TrackSessionStart(firstSessionStart);
        VibeGrowthSDK.TrackSessionStart(secondSessionStart);
        EventuallyEquals(config, "1", $@"
            SELECT count()
            FROM session_events
            WHERE device_id = {SqlString(deviceId)}
              AND is_first_session = 1
            FORMAT TSVRaw
        ");
        EventuallyEquals(config, "1", $@"
            SELECT count()
            FROM session_events
            WHERE device_id = {SqlString(deviceId)}
              AND is_first_session = 0
            FORMAT TSVRaw
        ");

        using var configDone = new ManualResetEventSlim(false);
        string configJson = null;
        string configError = null;
        VibeGrowthSDK.GetConfig(
            value =>
            {
                configJson = value;
                configDone.Set();
            },
            error =>
            {
                configError = error;
                configDone.Set();
            }
        );
        WaitForSignal("SDK config", configDone, TimeSpan.FromSeconds(20));
        if (!string.IsNullOrEmpty(configError))
        {
            throw new InvalidOperationException($"Config failed: {configError}");
        }
        if (configJson != "{}")
        {
            throw new InvalidOperationException($"Unexpected config response: {configJson}");
        }

        Debug.Log($"[VibeGrowthPlayerE2E] verified deviceId={deviceId} userId={userId} productId={productId}");
    }

    private static void WaitForSignal(string label, ManualResetEventSlim signal, TimeSpan timeout)
    {
        if (!signal.Wait(timeout))
        {
            throw new TimeoutException($"{label} timed out");
        }
    }

    private static void EventuallyEquals(SdkE2eConfig config, string expected, string query)
    {
        var deadline = DateTimeOffset.UtcNow.AddSeconds(20);
        var lastValue = "";
        string lastError = null;

        while (DateTimeOffset.UtcNow < deadline)
        {
            try
            {
                lastValue = RunClickHouseQuery(config, query);
                if (lastValue == expected)
                {
                    return;
                }
            }
            catch (Exception error)
            {
                lastError = error.Message;
            }

            Thread.Sleep(500);
        }

        throw new TimeoutException($"Timed out waiting for ClickHouse query result. expected={expected}, lastValue={lastValue}, lastError={lastError}");
    }

    private static string RunClickHouseQuery(SdkE2eConfig config, string query)
    {
        var url = $"{config.ClickHouseUrl}/?database={Uri.EscapeDataString(config.ClickHouseDatabase)}&wait_end_of_query=1";
        var request = (HttpWebRequest)WebRequest.Create(url);
        request.Method = "POST";
        request.ContentType = "text/plain";
        request.Timeout = 5000;
        request.ReadWriteTimeout = 5000;

        var bytes = Encoding.UTF8.GetBytes(query.Trim());
        request.ContentLength = bytes.Length;
        using (var stream = request.GetRequestStream())
        {
            stream.Write(bytes, 0, bytes.Length);
        }

        try
        {
            using (var response = (HttpWebResponse)request.GetResponse())
            using (var stream = response.GetResponseStream())
            using (var reader = new StreamReader(stream))
            {
                return reader.ReadToEnd().Trim();
            }
        }
        catch (WebException error)
        {
            var response = error.Response as HttpWebResponse;
            if (response == null)
            {
                throw;
            }

            using (var stream = response.GetResponseStream())
            using (var reader = new StreamReader(stream))
            {
                throw new InvalidOperationException($"ClickHouse query failed: HTTP {(int)response.StatusCode} {reader.ReadToEnd()}");
            }
        }
    }

    private static void ResetSdkForTests()
    {
        var sdkType = typeof(VibeGrowthSDK);
        sdkType.GetField("_initialized", BindingFlags.Static | BindingFlags.NonPublic)?.SetValue(null, false);
        sdkType.GetField("_bridge", BindingFlags.Static | BindingFlags.NonPublic)?.SetValue(null, null);
    }

    private static string SqlString(string value)
    {
        return $"'{value.Replace("'", "''")}'";
    }

    private static void WriteResults(string result, string error)
    {
        var path = Environment.GetEnvironmentVariable("VG_UNITY_PLAYER_E2E_RESULTS_PATH");
        if (string.IsNullOrWhiteSpace(path))
        {
            path = Path.Combine(Directory.GetCurrentDirectory(), "PlayerE2EResults.xml");
        }

        Directory.CreateDirectory(Path.GetDirectoryName(path));
        var failure = string.IsNullOrEmpty(error)
            ? ""
            : $"<failure><message>{EscapeXml(error)}</message></failure>";
        File.WriteAllText(
            path,
            $"<test-run result=\"{result}\"><test-suite name=\"VibeGrowthUnityPlayerE2E\" result=\"{result}\">{failure}</test-suite></test-run>",
            Encoding.UTF8
        );
    }

    private static string EscapeXml(string value)
    {
        return value
            .Replace("&", "&amp;")
            .Replace("<", "&lt;")
            .Replace(">", "&gt;")
            .Replace("\"", "&quot;")
            .Replace("'", "&apos;");
    }

    private sealed class SdkE2eConfig
    {
        public bool Enabled { get; private set; }
        public string AppId { get; private set; } = "sm_app_sdk_e2e";
        public string ApiKey { get; private set; } = "sk_live_sdk_e2e_local_only";
        public string BaseUrl { get; private set; } = "http://127.0.0.1:8000";
        public string ClickHouseUrl { get; private set; } = "http://127.0.0.1:8123";
        public string ClickHouseDatabase { get; private set; } = "scalemonk";

        public static SdkE2eConfig Load()
        {
            var config = new SdkE2eConfig
            {
                Enabled = Environment.GetEnvironmentVariable("VIBEGROWTH_SDK_E2E") == "1",
            };

            if (File.Exists(ConfigPath))
            {
                var json = File.ReadAllText(ConfigPath);
                config.Enabled = BooleanField(json, "enabled") ?? config.Enabled;
                config.AppId = StringField(json, "appId") ?? config.AppId;
                config.ApiKey = StringField(json, "apiKey") ?? config.ApiKey;
                config.BaseUrl = StringField(json, "baseUrl") ?? config.BaseUrl;
                config.ClickHouseUrl = StringField(json, "clickHouseUrl") ?? config.ClickHouseUrl;
                config.ClickHouseDatabase = StringField(json, "clickHouseDatabase") ?? config.ClickHouseDatabase;
            }

            config.AppId = Environment.GetEnvironmentVariable("VIBEGROWTH_SDK_E2E_APP_ID") ?? config.AppId;
            config.ApiKey = Environment.GetEnvironmentVariable("VIBEGROWTH_SDK_E2E_API_KEY") ?? config.ApiKey;
            config.BaseUrl = NormalizeLoopback(Environment.GetEnvironmentVariable("VIBEGROWTH_SDK_E2E_BASE_URL") ?? config.BaseUrl);
            config.ClickHouseUrl = NormalizeLoopback(Environment.GetEnvironmentVariable("VIBEGROWTH_SDK_E2E_CLICKHOUSE_URL") ?? config.ClickHouseUrl);
            config.ClickHouseDatabase = Environment.GetEnvironmentVariable("VIBEGROWTH_SDK_E2E_CLICKHOUSE_DATABASE") ?? config.ClickHouseDatabase;
            return config;
        }

        private static string NormalizeLoopback(string value)
        {
            return value.Replace("[::1]", "127.0.0.1");
        }

        private static bool? BooleanField(string json, string name)
        {
            var match = Regex.Match(json, $"\"{Regex.Escape(name)}\"\\s*:\\s*(true|false)");
            return match.Success ? bool.Parse(match.Groups[1].Value) : (bool?)null;
        }

        private static string StringField(string json, string name)
        {
            var match = Regex.Match(json, $"\"{Regex.Escape(name)}\"\\s*:\\s*\"([^\"]*)\"");
            return match.Success ? match.Groups[1].Value : null;
        }
    }
}
