using System;
using System.Collections.Generic;

namespace VibeGrowth
{
    public static class VibeGrowthSDK
    {
        private static IVibeGrowthNativeBridge _bridge;
        private static bool _initialized;

        public static void Initialize(string appId, string apiKey, Action onSuccess = null, Action<string> onError = null)
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

            _bridge.Initialize(appId, apiKey, () =>
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
            var amount = Convert.ToDouble(data["amount"]);
            var currency = (string)data["currency"];
            var productId = (string)data["productId"];
            _bridge.TrackPurchase(amount, currency, productId);
        }

        public static void TrackAdRevenue(Dictionary<string, object> data)
        {
            CheckInitialized();
            var source = (string)data["source"];
            var revenue = Convert.ToDouble(data["revenue"]);
            var currency = (string)data["currency"];
            _bridge.TrackAdRevenue(source, revenue, currency);
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
