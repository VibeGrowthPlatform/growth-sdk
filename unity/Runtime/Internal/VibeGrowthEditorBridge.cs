using System;
using UnityEngine;

namespace VibeGrowth
{
    internal class VibeGrowthEditorBridge : IVibeGrowthNativeBridge
    {
        public void Initialize(string appId, string apiKey, Action onSuccess, Action<string> onError)
        {
            Debug.Log($"[VibeGrowth] Initialize called with appId={appId}");
            onSuccess?.Invoke();
        }

        public void SetUserId(string userId)
        {
            Debug.Log($"[VibeGrowth] SetUserId called with userId={userId}");
        }

        public string GetUserId()
        {
            Debug.Log("[VibeGrowth] GetUserId called");
            return null;
        }

        public void TrackPurchase(double amount, string currency, string productId)
        {
            Debug.Log($"[VibeGrowth] TrackPurchase called with amount={amount}, currency={currency}, productId={productId}");
        }

        public void TrackAdRevenue(string source, double revenue, string currency)
        {
            Debug.Log($"[VibeGrowth] TrackAdRevenue called with source={source}, revenue={revenue}, currency={currency}");
        }
    }
}
