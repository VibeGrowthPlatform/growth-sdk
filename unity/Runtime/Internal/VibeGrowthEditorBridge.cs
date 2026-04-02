using System;
using UnityEngine;

namespace VibeGrowth
{
    internal class VibeGrowthEditorBridge : IVibeGrowthNativeBridge
    {
        private bool _initialized;
        private string _userId;
        private string _configJson = "{}";
        private bool _hasTrackedFirstSession;

        public void Initialize(string appId, string apiKey, string baseUrl, Action onSuccess, Action<string> onError)
        {
            _initialized = true;
            _configJson = string.IsNullOrEmpty(baseUrl)
                ? "{}"
                : $"{{\"base_url\":\"{baseUrl}\"}}";
            Debug.Log($"[VibeGrowth] Initialize called with appId={appId}");
            onSuccess?.Invoke();
        }

        public void SetUserId(string userId)
        {
            _userId = userId;
            Debug.Log($"[VibeGrowth] SetUserId called with userId={userId}");
        }

        public string GetUserId()
        {
            Debug.Log("[VibeGrowth] GetUserId called");
            return _userId;
        }

        public void TrackPurchase(double pricePaid, string currency, string productId)
        {
            Debug.Log($"[VibeGrowth] TrackPurchase called with pricePaid={pricePaid}, currency={currency}, productId={productId}");
        }

        public void TrackAdRevenue(string source, double revenue, string currency)
        {
            Debug.Log($"[VibeGrowth] TrackAdRevenue called with source={source}, revenue={revenue}, currency={currency}");
        }

        public void TrackSessionStart(string sessionStart)
        {
            var isFirstSession = !_hasTrackedFirstSession;
            if (isFirstSession)
            {
                _hasTrackedFirstSession = true;
            }

            Debug.Log($"[VibeGrowth] TrackSessionStart called with sessionStart={sessionStart}, isFirstSession={isFirstSession}, userId={_userId}");
        }

        public void GetConfig(Action<string> onSuccess, Action<string> onError)
        {
            if (!_initialized)
            {
                onError?.Invoke("VibeGrowthSDK must be initialized before use. Call VibeGrowthSDK.Initialize() first.");
                return;
            }

            onSuccess?.Invoke(_configJson);
        }
    }
}
