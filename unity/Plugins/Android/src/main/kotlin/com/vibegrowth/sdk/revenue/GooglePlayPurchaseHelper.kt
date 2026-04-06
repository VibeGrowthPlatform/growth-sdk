package com.vibegrowth.sdk.revenue

import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase

object GooglePlayPurchaseHelper {

    data class PurchaseInfo(
        val pricePaid: Double,
        val currency: String,
        val productId: String
    )

    fun extractPurchaseInfo(
        purchase: Purchase,
        productDetails: ProductDetails
    ): PurchaseInfo {
        val productId = productDetails.productId

        val oneTime = productDetails.oneTimePurchaseOfferDetails
        if (oneTime != null) {
            return PurchaseInfo(
                pricePaid = oneTime.priceAmountMicros / 1_000_000.0,
                currency = oneTime.priceCurrencyCode,
                productId = productId,
            )
        }

        val subscriptionOffers = productDetails.subscriptionOfferDetails
        if (!subscriptionOffers.isNullOrEmpty()) {
            val phases = subscriptionOffers[0].pricingPhases.pricingPhaseList
            if (phases.isNotEmpty()) {
                val recurringPhase = phases.last()
                return PurchaseInfo(
                    pricePaid = recurringPhase.priceAmountMicros / 1_000_000.0,
                    currency = recurringPhase.priceCurrencyCode,
                    productId = productId,
                )
            }
        }

        return PurchaseInfo(pricePaid = 0.0, currency = "USD", productId = productId)
    }
}
