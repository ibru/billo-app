//  Created by Jiri Urbasek on 11/26/25.

import Testing
import SwiftUI
import UIKit
@testable import Billo

@MainActor
@Suite("DesignSystem Category Mapping")
struct DesignSystemCategoryMappingTests {
    @Test func whenIconReceivesPluralName_thenReturnsUtilityGlyph() {
        let icon = DesignSystem.Icon.categoryIcon(for: "Utilities")

        #expect(icon == DesignSystem.Icon.categoryUtility)
    }

    @Test func whenTokenMissing_thenIconFallsBackToCategoryName() {
        let icon = DesignSystem.Icon.categoryIcon(for: "   Mortgage   ")

        #expect(icon == DesignSystem.Icon.categoryHousing)
    }

    @Test func whenColorTokenUsesVariant_thenReturnsSameColorAsCanonicalToken() {
        let baseline = UIColor(DesignSystem.Color.categoryColor(for: "utility"))
        let variant = UIColor(DesignSystem.Color.categoryColor(for: "Utilities"))

        #expect(variant == baseline)
    }
}
