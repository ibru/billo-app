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
@Suite("Color Hex Parsing")
struct ColorHexParsingTests {
    @Test func whenParsingSixDigitHex_thenColorComponentsMatch() {
        let color = Color(hex: "#34C759")

        expectComponents(of: color, red: 0x34, green: 0xC7, blue: 0x59)
    }

    @Test func whenParsingHexWithoutHashPrefix_thenColorComponentsMatch() {
        let color = Color(hex: "5856D6")

        expectComponents(of: color, red: 0x58, green: 0x56, blue: 0xD6)
    }

    @Test func whenParsingInvalidHex_thenFallsBackToGray() {
        let invalid = Color(hex: "not-a-color")
        let gray = Color(hex: DesignSystem.Color.CategoryPalette.other)

        expectSameComponents(invalid, gray)
    }

    @Test func whenParsingEmptyString_thenFallsBackToGray() {
        let empty = Color(hex: "")
        let gray = Color(hex: DesignSystem.Color.CategoryPalette.other)

        expectSameComponents(empty, gray)
    }
}

// MARK: - Assertion Helpers

@MainActor
private func expectComponents(
    of color: Color,
    red: UInt32,
    green: UInt32,
    blue: UInt32,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let components = rgbaComponents(of: color)
    let tolerance = 0.01

    #expect(abs(components.red - Double(red) / 255) < tolerance, sourceLocation: sourceLocation)
    #expect(abs(components.green - Double(green) / 255) < tolerance, sourceLocation: sourceLocation)
    #expect(abs(components.blue - Double(blue) / 255) < tolerance, sourceLocation: sourceLocation)
}

@MainActor
private func expectSameComponents(
    _ lhs: Color,
    _ rhs: Color,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let lhsComponents = rgbaComponents(of: lhs)
    let rhsComponents = rgbaComponents(of: rhs)
    let tolerance = 0.01

    #expect(abs(lhsComponents.red - rhsComponents.red) < tolerance, sourceLocation: sourceLocation)
    #expect(abs(lhsComponents.green - rhsComponents.green) < tolerance, sourceLocation: sourceLocation)
    #expect(abs(lhsComponents.blue - rhsComponents.blue) < tolerance, sourceLocation: sourceLocation)
}

private func rgbaComponents(of color: Color) -> (red: Double, green: Double, blue: Double, alpha: Double) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

#if canImport(UIKit)
    PlatformColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
#elseif canImport(AppKit)
    let converted = PlatformColor(color).usingColorSpace(.sRGB) ?? PlatformColor(color)
    converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
#endif

    return (Double(red), Double(green), Double(blue), Double(alpha))
}
