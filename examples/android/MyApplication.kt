import android.app.Application
import com.vibegrowth.sdk.VibeGrowthSDK

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        VibeGrowthSDK.initialize(
            context = this,
            appId = "your-app-id",
            apiKey = "your-api-key",
            baseUrl = "https://api.vibegrowth.com",
        )
    }
}
