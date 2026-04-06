package com.vibegrowth.sdk.revenue

import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

class GooglePlayPurchaseHelperTest {

    @Test
    fun extractsOneTimePurchasePrice() {
        val offerDetails = mockk<ProductDetails.OneTimePurchaseOfferDetails> {
            every { priceAmountMicros } returns 4_990_000L
            every { priceCurrencyCode } returns "USD"
        }
        val productDetails = mockk<ProductDetails> {
            every { productId } returns "gem_pack_100"
            every { oneTimePurchaseOfferDetails } returns offerDetails
            every { subscriptionOfferDetails } returns null
        }
        val purchase = mockk<Purchase>()

        val info = GooglePlayPurchaseHelper.extractPurchaseInfo(purchase, productDetails)

        assertEquals("gem_pack_100", info.productId)
        assertEquals(4.99, info.pricePaid, 0.001)
        assertEquals("USD", info.currency)
    }

    @Test
    fun extractsSubscriptionRecurringPrice() {
        val trialPhase = mockk<ProductDetails.PricingPhase> {
            every { priceAmountMicros } returns 0L
            every { priceCurrencyCode } returns "EUR"
        }
        val recurringPhase = mockk<ProductDetails.PricingPhase> {
            every { priceAmountMicros } returns 9_990_000L
            every { priceCurrencyCode } returns "EUR"
        }
        val pricingPhases = mockk<ProductDetails.PricingPhases> {
            every { pricingPhaseList } returns listOf(trialPhase, recurringPhase)
        }
        val subscriptionOffer = mockk<ProductDetails.SubscriptionOfferDetails> {
            every { this@mockk.pricingPhases } returns pricingPhases
        }
        val productDetails = mockk<ProductDetails> {
            every { productId } returns "premium_monthly"
            every { oneTimePurchaseOfferDetails } returns null
            every { subscriptionOfferDetails } returns listOf(subscriptionOffer)
        }
        val purchase = mockk<Purchase>()

        val info = GooglePlayPurchaseHelper.extractPurchaseInfo(purchase, productDetails)

        assertEquals("premium_monthly", info.productId)
        assertEquals(9.99, info.pricePaid, 0.001)
        assertEquals("EUR", info.currency)
    }

    @Test
    fun fallsBackWhenNoPricingAvailable() {
        val productDetails = mockk<ProductDetails> {
            every { productId } returns "unknown_product"
            every { oneTimePurchaseOfferDetails } returns null
            every { subscriptionOfferDetails } returns null
        }
        val purchase = mockk<Purchase>()

        val info = GooglePlayPurchaseHelper.extractPurchaseInfo(purchase, productDetails)

        assertEquals("unknown_product", info.productId)
        assertEquals(0.0, info.pricePaid, 0.001)
        assertEquals("USD", info.currency)
    }

    @Test
    fun handlesEmptySubscriptionOfferDetails() {
        val productDetails = mockk<ProductDetails> {
            every { productId } returns "sub_empty"
            every { oneTimePurchaseOfferDetails } returns null
            every { subscriptionOfferDetails } returns emptyList()
        }
        val purchase = mockk<Purchase>()

        val info = GooglePlayPurchaseHelper.extractPurchaseInfo(purchase, productDetails)

        assertEquals("sub_empty", info.productId)
        assertEquals(0.0, info.pricePaid, 0.001)
        assertEquals("USD", info.currency)
    }

    @Test
    fun prefersOneTimePurchaseOverSubscription() {
        val oneTimeOffer = mockk<ProductDetails.OneTimePurchaseOfferDetails> {
            every { priceAmountMicros } returns 1_990_000L
            every { priceCurrencyCode } returns "GBP"
        }
        val recurringPhase = mockk<ProductDetails.PricingPhase> {
            every { priceAmountMicros } returns 9_990_000L
            every { priceCurrencyCode } returns "GBP"
        }
        val pricingPhases = mockk<ProductDetails.PricingPhases> {
            every { pricingPhaseList } returns listOf(recurringPhase)
        }
        val subscriptionOffer = mockk<ProductDetails.SubscriptionOfferDetails> {
            every { this@mockk.pricingPhases } returns pricingPhases
        }
        val productDetails = mockk<ProductDetails> {
            every { productId } returns "dual_product"
            every { oneTimePurchaseOfferDetails } returns oneTimeOffer
            every { subscriptionOfferDetails } returns listOf(subscriptionOffer)
        }
        val purchase = mockk<Purchase>()

        val info = GooglePlayPurchaseHelper.extractPurchaseInfo(purchase, productDetails)

        assertEquals(1.99, info.pricePaid, 0.001)
        assertEquals("GBP", info.currency)
    }
}
