using System;

namespace VibeGrowth
{
    internal interface IVibeGrowthNativeBridge
    {
        void Initialize(string appId, string apiKey, Action onSuccess, Action<string> onError);
        void SetUserId(string userId);
        string GetUserId();
        void TrackPurchase(double amount, string currency, string productId);
        void TrackAdRevenue(string source, double revenue, string currency);
    }
}
