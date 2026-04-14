#if UNITY_ANDROID
using System;
using UnityEngine;

namespace VibeGrowth
{
    internal class VibeGrowthAndroidBridge : IVibeGrowthNativeBridge
    {
        private AndroidJavaObject _sdk;

        public VibeGrowthAndroidBridge()
        {
            using (var sdkClass = new AndroidJavaClass("com.vibegrowth.sdk.VibeGrowthSDK"))
            {
                _sdk = sdkClass.GetStatic<AndroidJavaObject>("INSTANCE");
            }
        }

        public void Initialize(string appId, string apiKey, string baseUrl, Action onSuccess, Action<string> onError)
        {
            AndroidJavaObject context;
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            using (var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
            {
                context = activity.Call<AndroidJavaObject>("getApplicationContext");
            }

            var callback = new InitCallback(onSuccess, onError);
            if (string.IsNullOrEmpty(baseUrl))
            {
                _sdk.Call("initialize", context, appId, apiKey, callback);
            }
            else
            {
                _sdk.Call("initialize", context, appId, apiKey, baseUrl, callback);
            }
        }

        public void SetUserId(string userId)
        {
            _sdk.Call("setUserId", userId);
        }

        public string GetUserId()
        {
            return _sdk.Call<string>("getUserId");
        }

        public void TrackPurchase(double pricePaid, string currency, string productId)
        {
            _sdk.Call("trackPurchase", pricePaid, currency, productId);
        }

        public void TrackAdRevenue(string source, double revenue, string currency)
        {
            _sdk.Call("trackAdRevenue", source, revenue, currency);
        }

        public void TrackSessionStart(string sessionStart)
        {
            _sdk.Call("trackSessionStart", sessionStart);
        }

        public void GetConfig(Action<string> onSuccess, Action<string> onError)
        {
            var callback = new ConfigCallback(onSuccess, onError);
            _sdk.Call("getConfig", callback);
        }

        private class InitCallback : AndroidJavaProxy
        {
            private readonly Action _onSuccess;
            private readonly Action<string> _onError;

            public InitCallback(Action onSuccess, Action<string> onError)
                : base("com.vibegrowth.sdk.VibeGrowthSDK$InitCallback")
            {
                _onSuccess = onSuccess;
                _onError = onError;
            }

            // Called from Java on background thread
            void onSuccess()
            {
                UnityMainThreadDispatcher.Enqueue(() => _onSuccess?.Invoke());
            }

            // Called from Java on background thread
            void onError(string error)
            {
                UnityMainThreadDispatcher.Enqueue(() => _onError?.Invoke(error));
            }
        }

        private class ConfigCallback : AndroidJavaProxy
        {
            private readonly Action<string> _onSuccess;
            private readonly Action<string> _onError;

            public ConfigCallback(Action<string> onSuccess, Action<string> onError)
                : base("com.vibegrowth.sdk.VibeGrowthSDK$ConfigCallback")
            {
                _onSuccess = onSuccess;
                _onError = onError;
            }

            void onSuccess(string configJson)
            {
                UnityMainThreadDispatcher.Enqueue(() => _onSuccess?.Invoke(configJson));
            }

            void onError(string error)
            {
                UnityMainThreadDispatcher.Enqueue(() => _onError?.Invoke(error));
            }
        }
    }
}
#endif
