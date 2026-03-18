#import <Foundation/Foundation.h>
#import "VibeGrowthSDK-Swift.h"

typedef void (*SuccessCallback)(void);
typedef void (*ErrorCallback)(const char *error);

extern "C" {

    void _vibegrowth_initialize(const char *appId, const char *apiKey,
                               SuccessCallback onSuccess, ErrorCallback onError) {
        NSString *nsAppId = [NSString stringWithUTF8String:appId];
        NSString *nsApiKey = [NSString stringWithUTF8String:apiKey];

        [[VibeGrowthSDK shared] initializeWithAppId:nsAppId apiKey:nsApiKey completion:^(BOOL success, NSString *error) {
            if (success) {
                if (onSuccess) {
                    onSuccess();
                }
            } else {
                if (onError) {
                    const char *errorStr = error ? strdup([error UTF8String]) : strdup("Unknown error");
                    onError(errorStr);
                    free((void *)errorStr);
                }
            }
        }];
    }

    void _vibegrowth_setUserId(const char *userId) {
        NSString *nsUserId = [NSString stringWithUTF8String:userId];
        [[VibeGrowthSDK shared] setUserId:nsUserId];
    }

    const char * _vibegrowth_getUserId(void) {
        NSString *userId = [[VibeGrowthSDK shared] getUserId];
        if (userId == nil) {
            return NULL;
        }
        return strdup([userId UTF8String]);
    }

    void _vibegrowth_trackPurchase(double amount, const char *currency, const char *productId) {
        NSString *nsCurrency = [NSString stringWithUTF8String:currency];
        NSString *nsProductId = [NSString stringWithUTF8String:productId];
        [[VibeGrowthSDK shared] trackPurchaseWithAmount:amount currency:nsCurrency productId:nsProductId];
    }

    void _vibegrowth_trackAdRevenue(const char *source, double revenue, const char *currency) {
        NSString *nsSource = [NSString stringWithUTF8String:source];
        NSString *nsCurrency = [NSString stringWithUTF8String:currency];
        [[VibeGrowthSDK shared] trackAdRevenueWithSource:nsSource revenue:revenue currency:nsCurrency];
    }

}
