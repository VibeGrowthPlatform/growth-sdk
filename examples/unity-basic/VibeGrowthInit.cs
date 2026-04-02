using UnityEngine;

namespace VibeGrowth.Sample
{
    public class VibeGrowthInit : MonoBehaviour
    {
        private void Start()
        {
            VibeGrowthSDK.Initialize(
                appId: "your-app-id",
                apiKey: "your-api-key",
                onSuccess: () => Debug.Log("Vibe Growth initialized"),
                onError: (error) => Debug.LogError("Vibe Growth init failed: " + error),
                baseUrl: "https://api.vibegrowth.com"
            );
        }
    }
}
