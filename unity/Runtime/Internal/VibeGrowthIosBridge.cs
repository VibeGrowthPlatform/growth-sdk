using System;
using System.Runtime.InteropServices;
using AOT;

namespace VibeGrowth
{
    internal class VibeGrowthIosBridge : IVibeGrowthNativeBridge
    {
        private static Action _onSuccess;
        private static Action<string> _onError;

        private delegate void SuccessCallback();
        private delegate void ErrorCallback(string error);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_initialize(string appId, string apiKey,
            SuccessCallback onSuccess, ErrorCallback onError);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_setUserId(string userId);

        [DllImport("__Internal")]
        private static extern string _vibegrowth_getUserId();

        [DllImport("__Internal")]
        private static extern void _vibegrowth_trackPurchase(double amount, string currency, string productId);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_trackAdRevenue(string source, double revenue, string currency);

        public void Initialize(string appId, string apiKey, Action onSuccess, Action<string> onError)
        {
            _onSuccess = onSuccess;
            _onError = onError;
            _vibegrowth_initialize(appId, apiKey, OnInitSuccess, OnInitError);
        }

        public void SetUserId(string userId)
        {
            _vibegrowth_setUserId(userId);
        }

        public string GetUserId()
        {
            return _vibegrowth_getUserId();
        }

        public void TrackPurchase(double amount, string currency, string productId)
        {
            _vibegrowth_trackPurchase(amount, currency, productId);
        }

        public void TrackAdRevenue(string source, double revenue, string currency)
        {
            _vibegrowth_trackAdRevenue(source, revenue, currency);
        }

        [MonoPInvokeCallback(typeof(SuccessCallback))]
        private static void OnInitSuccess()
        {
            UnityMainThreadDispatcher.Enqueue(() => _onSuccess?.Invoke());
        }

        [MonoPInvokeCallback(typeof(ErrorCallback))]
        private static void OnInitError(string error)
        {
            UnityMainThreadDispatcher.Enqueue(() => _onError?.Invoke(error));
        }
    }
}
