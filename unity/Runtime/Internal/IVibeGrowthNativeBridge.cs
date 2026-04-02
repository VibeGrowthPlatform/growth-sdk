using System;

namespace VibeGrowth
{
    internal interface IVibeGrowthNativeBridge
    {
        void Initialize(string appId, string apiKey, string baseUrl, Action onSuccess, Action<string> onError);
        void SetUserId(string userId);
        string GetUserId();
        void TrackPurchase(double pricePaid, string currency, string productId);
        void TrackAdRevenue(string source, double revenue, string currency);
        void TrackSessionStart(string sessionStart);
        void GetConfig(Action<string> onSuccess, Action<string> onError);
    }
}
