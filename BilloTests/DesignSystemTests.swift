//  Created by Jiri Urbasek on 11/26/25.

import Testing
import SwiftUI
@testable import Billo

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
#endif

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
        let baseline = PlatformColor(DesignSystem.Color.categoryColor(for: "utility"))
        let variant = PlatformColor(DesignSystem.Color.categoryColor(for: "Utilities"))

        #expect(variant == baseline)
    }
}
