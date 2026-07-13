//  Created by Jiri Urbasek on 7/13/26.

import Testing
import Foundation
@testable import Billo

@Suite("FreeTierLimits")
struct FreeTierLimitsTests {

    // MARK: - Bill cap

    @Test func whenBelowBillLimit_thenCanAddBill() {
        #expect(FreeTierLimits.canAddBill(currentCount: 14, isPro: false))
    }

    @Test func whenAtBillLimit_thenCannotAddBill() {
        #expect(FreeTierLimits.canAddBill(currentCount: 15, isPro: false) == false)
    }

    @Test func whenAtBillLimitAndPro_thenCanAddBill() {
        #expect(FreeTierLimits.canAddBill(currentCount: 15, isPro: true))
    }

    @Test func whenOverBillLimit_thenCannotAddBill() {
        // Over-cap state can exist via CloudKit sync from a formerly-Pro device.
        #expect(FreeTierLimits.canAddBill(currentCount: 20, isPro: false) == false)
    }

    // MARK: - Income cap

    @Test func whenBelowIncomeLimit_thenCanAddIncome() {
        #expect(FreeTierLimits.canAddIncome(currentCount: 1, isPro: false))
    }

    @Test func whenAtIncomeLimit_thenCannotAddIncome() {
        #expect(FreeTierLimits.canAddIncome(currentCount: 2, isPro: false) == false)
    }

    @Test func whenAtIncomeLimitAndPro_thenCanAddIncome() {
        #expect(FreeTierLimits.canAddIncome(currentCount: 2, isPro: true))
    }

    @Test func whenOverIncomeLimit_thenCannotAddIncome() {
        // Over-cap state can exist via CloudKit sync from a formerly-Pro device.
        #expect(FreeTierLimits.canAddIncome(currentCount: 5, isPro: false) == false)
    }

    // MARK: - Partial payments

    @Test func whenPaymentCoversRemainingBalance_thenCanRecordPayment() {
        #expect(FreeTierLimits.canRecordPayment(amount: 100, remainingBalance: 100, isPro: false))
    }

    @Test func whenPaymentExceedsRemainingBalance_thenCanRecordPayment() {
        // Overpayment is not a partial payment — stays free.
        #expect(FreeTierLimits.canRecordPayment(amount: 120, remainingBalance: 100, isPro: false))
    }

    @Test func whenPaymentBelowRemainingBalance_thenCannotRecordPayment() {
        #expect(FreeTierLimits.canRecordPayment(amount: 40, remainingBalance: 100, isPro: false) == false)
    }

    @Test func whenPaymentBelowRemainingBalanceAndPro_thenCanRecordPayment() {
        #expect(FreeTierLimits.canRecordPayment(amount: 40, remainingBalance: 100, isPro: true))
    }

    @Test func whenPayingOffRestOfPartiallyPaidOccurrence_thenCanRecordPayment() {
        // Occurrence already partially paid elsewhere: settling the remainder is free.
        #expect(FreeTierLimits.canRecordPayment(amount: 60, remainingBalance: 60, isPro: false))
    }

    // MARK: - Feature switches

    @Test func whenNotPro_thenCustomRecurrenceChartsAndExportAreLocked() {
        #expect(FreeTierLimits.canSelectCustomRecurrence(isPro: false) == false)
        #expect(FreeTierLimits.canViewCharts(isPro: false) == false)
        #expect(FreeTierLimits.canExportData(isPro: false) == false)
    }

    @Test func whenPro_thenAllGatesOpen() {
        #expect(FreeTierLimits.canSelectCustomRecurrence(isPro: true))
        #expect(FreeTierLimits.canViewCharts(isPro: true))
        #expect(FreeTierLimits.canExportData(isPro: true))
    }
}
