using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using VibeGrowth;

public sealed class VibeGrowthUnityEndToEndTests
{
    private const string ConfigPath = "/tmp/vibegrowth-sdk-e2e.json";
    private const string DeviceIdKey = "vibegrowth_device_id";
    private const string UserIdKey = "vibegrowth_user_id";
    private const string HasTrackedFirstSessionKey = "vibegrowth_has_tracked_first_session";

    [UnityTest]
    public IEnumerator FullUnitySdkFlowPersistsThroughRealBackend()
    {
        var config = SdkE2eConfig.Load();
        if (!config.Enabled)
        {
            Assert.Ignore("SDK real-backend e2e is disabled");
        }

        ResetSdkForTests();

        var deviceId = $"unity-e2e-{Guid.NewGuid()}";
        var userId = $"user-{Guid.NewGuid()}";
        var productId = $"product-{Guid.NewGuid()}";
        var firstSessionStart = "2026-04-02T10:00:00+00:00";
        var secondSessionStart = "2026-04-02T10:05:00+00:00";

        PlayerPrefs.SetString(DeviceIdKey, deviceId);
        PlayerPrefs.DeleteKey(UserIdKey);
        PlayerPrefs.DeleteKey(HasTrackedFirstSessionKey);
        PlayerPrefs.Save();

        var initDone = false;
        string initError = null;
        VibeGrowthSDK.Initialize(
            config.AppId,
            config.ApiKey,
            onSuccess: () => initDone = true,
            onError: error =>
            {
                initError = error;
                initDone = true;
            },
            baseUrl: config.BaseUrl
        );

        yield return WaitUntil("SDK initialization", () => initDone, 20);
        Assert.IsNull(initError, $"Init failed: {initError}");

        yield return EventuallyEquals(
            config,
            "unity",
            $@"
                SELECT platform
                FROM devices FINAL
                WHERE device_id = {SqlString(deviceId)}
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            "
        );
        yield return EventuallyEquals(
            config,
            "2.1.0",
            $@"
                SELECT sdk_version
                FROM devices FINAL
                WHERE device_id = {SqlString(deviceId)}
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            "
        );

        VibeGrowthSDK.SetUserId(userId);
        Assert.AreEqual(userId, VibeGrowthSDK.GetUserId());
        yield return EventuallyEquals(
            config,
            userId,
            $@"
                SELECT ifNull(user_id, '')
                FROM devices FINAL
                WHERE device_id = {SqlString(deviceId)}
                ORDER BY updated_at DESC
                LIMIT 1
                FORMAT TSVRaw
            "
        );

        VibeGrowthSDK.TrackPurchase(new Dictionary<string, object>
        {
            { "pricePaid", 4.99 },
            { "currency", "USD" },
            { "productId", productId },
        });
        yield return EventuallyEquals(
            config,
            productId,
            $@"
                SELECT ifNull(product_id, '')
                FROM revenue_events
                WHERE device_id = {SqlString(deviceId)}
                  AND product_id = {SqlString(productId)}
                ORDER BY received_at DESC
                LIMIT 1
                FORMAT TSVRaw
            "
        );

        VibeGrowthSDK.TrackAdRevenue(new Dictionary<string, object>
        {
            { "source", "admob" },
            { "revenue", 0.02 },
            { "currency", "USD" },
        });
        yield return EventuallyEquals(
            config,
            "ad_revenue",
            $@"
                SELECT revenue_type
                FROM revenue_events
                WHERE device_id = {SqlString(deviceId)}
                  AND ad_source = 'admob'
                ORDER BY received_at DESC
                LIMIT 1
                FORMAT TSVRaw
            "
        );

        VibeGrowthSDK.TrackSessionStart(firstSessionStart);
        VibeGrowthSDK.TrackSessionStart(secondSessionStart);
        yield return EventuallyEquals(
            config,
            "1",
            $@"
                SELECT count()
                FROM session_events
                WHERE device_id = {SqlString(deviceId)}
                  AND is_first_session = 1
                FORMAT TSVRaw
            "
        );
        yield return EventuallyEquals(
            config,
            "1",
            $@"
                SELECT count()
                FROM session_events
                WHERE device_id = {SqlString(deviceId)}
                  AND is_first_session = 0
                FORMAT TSVRaw
            "
        );

        var configDone = false;
        string configJson = null;
        string configError = null;
        VibeGrowthSDK.GetConfig(
            value =>
            {
                configJson = value;
                configDone = true;
            },
            error =>
            {
                configError = error;
                configDone = true;
            }
        );

        yield return WaitUntil("SDK config", () => configDone, 20);
        Assert.IsNull(configError, $"Config failed: {configError}");
        Assert.AreEqual("{}", configJson);
    }

    private static IEnumerator WaitUntil(string label, Func<bool> predicate, float timeoutSeconds)
    {
        var deadline = DateTimeOffset.UtcNow.AddSeconds(timeoutSeconds);
        while (!predicate())
        {
            if (DateTimeOffset.UtcNow > deadline)
            {
                Assert.Fail($"{label} timed out");
            }
            yield return null;
        }
    }

    private static IEnumerator EventuallyEquals(
        SdkE2eConfig config,
        string expected,
        string query,
        float timeoutSeconds = 20,
        float pollIntervalSeconds = 0.5f
    )
    {
        var deadline = DateTimeOffset.UtcNow.AddSeconds(timeoutSeconds);
        var lastValue = "";
        string lastError = null;

        while (DateTimeOffset.UtcNow < deadline)
        {
            try
            {
                lastValue = RunClickHouseQuery(config, query);
                if (lastValue == expected)
                {
                    yield break;
                }
            }
            catch (Exception error)
            {
                lastError = error.Message;
            }

            yield return new WaitForSeconds(pollIntervalSeconds);
        }

        Assert.Fail($"Timed out waiting for ClickHouse query result. expected={expected}, lastValue={lastValue}, lastError={lastError}");
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

    private sealed class SdkE2eConfig
    {
        public bool Enabled { get; private set; }
        public string AppId { get; private set; } = "sm_app_sdk_e2e";
        public string ApiKey { get; private set; } = "sk_live_sdk_e2e_local_only";
        public string BaseUrl { get; private set; } = "http://[::1]:8000";
        public string ClickHouseUrl { get; private set; } = "http://[::1]:8123";
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
