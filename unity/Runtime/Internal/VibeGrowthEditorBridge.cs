using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using UnityEngine;

namespace VibeGrowth
{
    internal class VibeGrowthEditorBridge : IVibeGrowthNativeBridge
    {
        private const string DefaultBaseUrl = "https://api.vibegrowin.ai";
        private const string DeviceIdKey = "vibegrowth_device_id";
        private const string UserIdKey = "vibegrowth_user_id";
        private const string HasTrackedFirstSessionKey = "vibegrowth_has_tracked_first_session";
        private const string Platform = "unity";
        private const string SdkVersion = "2.1.0";

        private bool _initialized;
        private string _appId;
        private string _apiKey;
        private string _baseUrl;
        private string _deviceId;
        private string _userId;
        private string _configJson = "{}";
        private SynchronizationContext _callbackContext;

        public void Initialize(string appId, string apiKey, string baseUrl, Action onSuccess, Action<string> onError)
        {
            _callbackContext = SynchronizationContext.Current;
            _appId = appId;
            _apiKey = apiKey;
            _baseUrl = string.IsNullOrWhiteSpace(baseUrl) ? DefaultBaseUrl : baseUrl.TrimEnd('/');
            _deviceId = GetOrCreateDeviceId();
            _userId = PlayerPrefs.GetString(UserIdKey, null);

            RunNetwork(
                () => Post("/api/sdk/init", new Dictionary<string, object>
                {
                    { "app_id", _appId },
                    { "device_id", _deviceId },
                    { "platform", Platform },
                    { "sdk_version", SdkVersion },
                    { "attribution", new Dictionary<string, object> { { "runtime", "unity-editor" } } },
                }),
                () =>
                {
                    _initialized = true;
                    Debug.Log($"[VibeGrowth] Initialized successfully (deviceId={_deviceId})");
                    onSuccess?.Invoke();
                },
                onError
            );
        }

        public void SetUserId(string userId)
        {
            _userId = userId;
            PlayerPrefs.SetString(UserIdKey, userId);
            PlayerPrefs.Save();
            RunNetwork(
                () => Post("/api/sdk/identify", new Dictionary<string, object>
                {
                    { "app_id", _appId },
                    { "device_id", _deviceId },
                    { "user_id", userId },
                }),
                () => Debug.Log($"[VibeGrowth] SetUserId synced (userId={userId})"),
                error => Debug.LogWarning($"[VibeGrowth] SetUserId sync failed: {error}")
            );
        }

        public string GetUserId()
        {
            Debug.Log("[VibeGrowth] GetUserId called");
            return _userId;
        }

        public void TrackPurchase(double pricePaid, string currency, string productId)
        {
            RunNetwork(
                () => Post("/api/sdk/revenue", new Dictionary<string, object>
                {
                    { "app_id", _appId },
                    { "device_id", _deviceId },
                    { "user_id", _userId },
                    { "revenue_type", "purchase" },
                    { "amount", pricePaid },
                    { "currency", currency },
                    { "product_id", productId },
                    { "timestamp", DateTimeOffset.UtcNow.ToString("o", CultureInfo.InvariantCulture) },
                }),
                () => Debug.Log($"[VibeGrowth] TrackPurchase synced (pricePaid={pricePaid}, currency={currency}, productId={productId})"),
                error => Debug.LogWarning($"[VibeGrowth] TrackPurchase sync failed: {error}")
            );
        }

        public void TrackAdRevenue(string source, double revenue, string currency)
        {
            RunNetwork(
                () => Post("/api/sdk/revenue", new Dictionary<string, object>
                {
                    { "app_id", _appId },
                    { "device_id", _deviceId },
                    { "user_id", _userId },
                    { "revenue_type", "ad_revenue" },
                    { "amount", revenue },
                    { "currency", currency },
                    { "ad_source", source },
                    { "timestamp", DateTimeOffset.UtcNow.ToString("o", CultureInfo.InvariantCulture) },
                }),
                () => Debug.Log($"[VibeGrowth] TrackAdRevenue synced (source={source}, revenue={revenue}, currency={currency})"),
                error => Debug.LogWarning($"[VibeGrowth] TrackAdRevenue sync failed: {error}")
            );
        }

        public void TrackSessionStart(string sessionStart)
        {
            var hasTrackedFirstSession = PlayerPrefs.GetInt(HasTrackedFirstSessionKey, 0) == 1;
            var isFirstSession = !hasTrackedFirstSession;
            if (!hasTrackedFirstSession)
            {
                PlayerPrefs.SetInt(HasTrackedFirstSessionKey, 1);
                PlayerPrefs.Save();
            }

            RunNetwork(
                () => Post("/api/sdk/session", new Dictionary<string, object>
                {
                    { "app_id", _appId },
                    { "device_id", _deviceId },
                    { "user_id", _userId },
                    { "session_start", sessionStart },
                    { "is_first_session", isFirstSession },
                }),
                () => Debug.Log($"[VibeGrowth] TrackSessionStart synced (sessionStart={sessionStart}, isFirstSession={isFirstSession})"),
                error => Debug.LogWarning($"[VibeGrowth] TrackSessionStart sync failed: {error}")
            );
        }

        public void GetConfig(Action<string> onSuccess, Action<string> onError)
        {
            if (!_initialized)
            {
                onError?.Invoke("VibeGrowthSDK must be initialized before use. Call VibeGrowthSDK.Initialize() first.");
                return;
            }

            RunNetwork(
                () =>
                {
                    var response = Request("GET", "/api/sdk/config", null);
                    _configJson = ExtractConfigJson(response);
                },
                () => onSuccess?.Invoke(_configJson),
                onError
            );
        }

        private string GetOrCreateDeviceId()
        {
            var existing = PlayerPrefs.GetString(DeviceIdKey, null);
            if (!string.IsNullOrEmpty(existing))
            {
                return existing;
            }

            var generated = $"unity-{Guid.NewGuid()}";
            PlayerPrefs.SetString(DeviceIdKey, generated);
            PlayerPrefs.Save();
            return generated;
        }

        private void RunNetwork(Action action, Action onSuccess, Action<string> onError)
        {
            if (Application.isBatchMode)
            {
                try
                {
                    action();
                    onSuccess?.Invoke();
                }
                catch (Exception error)
                {
                    onError?.Invoke(error.Message);
                }
                return;
            }

            ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    action();
                    PostCallback(onSuccess);
                }
                catch (Exception error)
                {
                    PostCallback(() => onError?.Invoke(error.Message));
                }
            });
        }

        private void Post(string path, Dictionary<string, object> body)
        {
            Request("POST", path, SerializeJson(body));
        }

        private string Request(string method, string path, string body)
        {
            var request = (HttpWebRequest)WebRequest.Create($"{_baseUrl}{path}");
            request.Method = method;
            request.Headers[HttpRequestHeader.Authorization] = $"Bearer {_apiKey}";
            request.Timeout = 10000;
            request.ReadWriteTimeout = 10000;
            request.KeepAlive = false;

            if (body != null)
            {
                var bytes = Encoding.UTF8.GetBytes(body);
                request.ContentType = "application/json";
                request.ContentLength = bytes.Length;
                using (var stream = request.GetRequestStream())
                {
                    stream.Write(bytes, 0, bytes.Length);
                }
            }

            try
            {
                using (var response = (HttpWebResponse)request.GetResponse())
                {
                    if (method != "GET")
                    {
                        return "";
                    }

                    using (var stream = response.GetResponseStream())
                    using (var reader = new StreamReader(stream))
                    {
                        return reader.ReadToEnd();
                    }
                }
            }
            catch (WebException error)
            {
                var response = error.Response as HttpWebResponse;
                var status = response == null ? "network error" : $"HTTP {(int)response.StatusCode}";
                var message = response == null ? error.Message : response.StatusDescription;
                throw new InvalidOperationException($"{status}: {message}", error);
            }
        }

        private void PostCallback(Action callback)
        {
            if (callback == null)
            {
                return;
            }

            if (_callbackContext == null || Application.isBatchMode)
            {
                callback();
                return;
            }

            _callbackContext.Post(_ => callback(), null);
        }

        private string SerializeJson(Dictionary<string, object> values)
        {
            var builder = new StringBuilder();
            builder.Append('{');
            var first = true;
            foreach (var pair in values)
            {
                if (pair.Value == null)
                {
                    continue;
                }

                if (!first)
                {
                    builder.Append(',');
                }

                first = false;
                builder.Append('"').Append(EscapeJson(pair.Key)).Append("\":");
                AppendJsonValue(builder, pair.Value);
            }
            builder.Append('}');
            return builder.ToString();
        }

        private void AppendJsonValue(StringBuilder builder, object value)
        {
            if (value == null)
            {
                builder.Append("null");
                return;
            }

            if (value is string stringValue)
            {
                builder.Append('"').Append(EscapeJson(stringValue)).Append('"');
                return;
            }

            if (value is bool boolValue)
            {
                builder.Append(boolValue ? "true" : "false");
                return;
            }

            if (value is int || value is long || value is float || value is double || value is decimal)
            {
                builder.Append(Convert.ToString(value, CultureInfo.InvariantCulture));
                return;
            }

            if (value is Dictionary<string, object> objectValue)
            {
                builder.Append(SerializeJson(objectValue));
                return;
            }

            builder.Append('"').Append(EscapeJson(value.ToString())).Append('"');
        }

        private string EscapeJson(string value)
        {
            return value
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\n", "\\n")
                .Replace("\r", "\\r")
                .Replace("\t", "\\t");
        }

        private string ExtractConfigJson(string response)
        {
            var markerIndex = response.IndexOf("\"config\"", StringComparison.Ordinal);
            if (markerIndex < 0)
            {
                return "{}";
            }

            var objectStart = response.IndexOf('{', markerIndex);
            if (objectStart < 0)
            {
                return "{}";
            }

            var depth = 0;
            var inString = false;
            var escaped = false;
            for (var i = objectStart; i < response.Length; i++)
            {
                var ch = response[i];
                if (escaped)
                {
                    escaped = false;
                    continue;
                }

                if (ch == '\\')
                {
                    escaped = true;
                    continue;
                }

                if (ch == '"')
                {
                    inString = !inString;
                    continue;
                }

                if (inString)
                {
                    continue;
                }

                if (ch == '{')
                {
                    depth++;
                }
                else if (ch == '}')
                {
                    depth--;
                    if (depth == 0)
                    {
                        return response.Substring(objectStart, i - objectStart + 1);
                    }
                }
            }

            return "{}";
        }
    }
}
