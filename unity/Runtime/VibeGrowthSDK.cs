using System;
using System.Collections.Generic;

namespace VibeGrowth
{
    public static class VibeGrowthSDK
    {
        private static IVibeGrowthNativeBridge _bridge;
        private static bool _initialized;

        public static void Initialize(
            string appId,
            string apiKey,
            Action onSuccess = null,
            Action<string> onError = null,
            string baseUrl = null
        )
        {
            if (_initialized)
            {
                onSuccess?.Invoke();
                return;
            }

#if UNITY_ANDROID && !UNITY_EDITOR
            _bridge = new VibeGrowthAndroidBridge();
#elif UNITY_IOS && !UNITY_EDITOR
            _bridge = new VibeGrowthIosBridge();
#else
            _bridge = new VibeGrowthEditorBridge();
#endif

            _bridge.Initialize(appId, apiKey, baseUrl, () =>
            {
                _initialized = true;
                onSuccess?.Invoke();
            }, onError);
        }

        public static void SetUserId(string userId)
        {
            CheckInitialized();
            _bridge.SetUserId(userId);
        }

        public static string GetUserId()
        {
            CheckInitialized();
            return _bridge.GetUserId();
        }

        public static void TrackPurchase(Dictionary<string, object> data)
        {
            CheckInitialized();
            var pricePaid = data.ContainsKey("pricePaid")
                ? Convert.ToDouble(data["pricePaid"])
                : Convert.ToDouble(data["amount"]);
            var currency = (string)data["currency"];
            var productId = data.ContainsKey("productId")
                ? data["productId"] as string
                : null;
            _bridge.TrackPurchase(pricePaid, currency, productId);
        }

        public static void TrackAdRevenue(Dictionary<string, object> data)
        {
            CheckInitialized();
            var source = (string)data["source"];
            var revenue = Convert.ToDouble(data["revenue"]);
            var currency = (string)data["currency"];
            _bridge.TrackAdRevenue(source, revenue, currency);
        }

        public static void TrackSessionStart(string sessionStart)
        {
            CheckInitialized();
            _bridge.TrackSessionStart(sessionStart);
        }

        public static void TrackSession(string sessionStart, int sessionDurationMs)
        {
            _ = sessionDurationMs;
            TrackSessionStart(sessionStart);
        }

        public static void GetConfig(Action<string> onSuccess, Action<string> onError = null)
        {
            CheckInitialized();
            _bridge.GetConfig(onSuccess, onError);
        }

        private static void CheckInitialized()
        {
            if (!_initialized)
            {
                throw new InvalidOperationException("VibeGrowthSDK must be initialized before use. Call VibeGrowthSDK.Initialize() first.");
            }
        }
    }
}
