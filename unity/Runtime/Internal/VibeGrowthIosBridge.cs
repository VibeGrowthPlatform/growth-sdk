using System;
using System.Runtime.InteropServices;
using AOT;

namespace VibeGrowth
{
    internal class VibeGrowthIosBridge : IVibeGrowthNativeBridge
    {
        private static Action _onInitSuccess;
        private static Action<string> _onInitError;
        private static Action<string> _onConfigSuccess;
        private static Action<string> _onConfigError;

        private delegate void SuccessCallback();
        private delegate void ErrorCallback(string error);
        private delegate void ConfigSuccessCallback(string configJson);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_initialize(string appId, string apiKey, string baseUrl,
            SuccessCallback onSuccess, ErrorCallback onError);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_setUserId(string userId);

        [DllImport("__Internal")]
        private static extern string _vibegrowth_getUserId();

        [DllImport("__Internal")]
        private static extern void _vibegrowth_trackPurchase(double pricePaid, string currency, string productId);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_trackAdRevenue(string source, double revenue, string currency);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_trackSessionStart(string sessionStart);

        [DllImport("__Internal")]
        private static extern void _vibegrowth_getConfig(ConfigSuccessCallback onSuccess, ErrorCallback onError);

        public void Initialize(string appId, string apiKey, string baseUrl, Action onSuccess, Action<string> onError)
        {
            _onInitSuccess = onSuccess;
            _onInitError = onError;
            _vibegrowth_initialize(appId, apiKey, baseUrl, OnInitSuccess, OnInitError);
        }

        public void SetUserId(string userId)
        {
            _vibegrowth_setUserId(userId);
        }

        public string GetUserId()
        {
            return _vibegrowth_getUserId();
        }

        public void TrackPurchase(double pricePaid, string currency, string productId)
        {
            _vibegrowth_trackPurchase(pricePaid, currency, productId);
        }

        public void TrackAdRevenue(string source, double revenue, string currency)
        {
            _vibegrowth_trackAdRevenue(source, revenue, currency);
        }

        public void TrackSessionStart(string sessionStart)
        {
            _vibegrowth_trackSessionStart(sessionStart);
        }

        public void GetConfig(Action<string> onSuccess, Action<string> onError)
        {
            _onConfigSuccess = onSuccess;
            _onConfigError = onError;
            _vibegrowth_getConfig(OnConfigSuccess, OnConfigError);
        }

        [MonoPInvokeCallback(typeof(SuccessCallback))]
        private static void OnInitSuccess()
        {
            UnityMainThreadDispatcher.Enqueue(() => _onInitSuccess?.Invoke());
        }

        [MonoPInvokeCallback(typeof(ErrorCallback))]
        private static void OnInitError(string error)
        {
            UnityMainThreadDispatcher.Enqueue(() => _onInitError?.Invoke(error));
        }

        [MonoPInvokeCallback(typeof(ConfigSuccessCallback))]
        private static void OnConfigSuccess(string configJson)
        {
            UnityMainThreadDispatcher.Enqueue(() => _onConfigSuccess?.Invoke(configJson));
        }

        [MonoPInvokeCallback(typeof(ErrorCallback))]
        private static void OnConfigError(string error)
        {
            UnityMainThreadDispatcher.Enqueue(() => _onConfigError?.Invoke(error));
        }
    }
}
