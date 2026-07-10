//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI

/// Preset color swatch grid for custom categories. Persists the chosen
/// value as a "#RRGGBB" hex string from `DesignSystem.Color.CategoryPalette`.
struct ColorSwatchPicker: View {
    @Binding var selectedHex: String

    private let swatches = DesignSystem.Color.CategoryPalette.swatches
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: DesignSystem.Spacing.small)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.small) {
            ForEach(swatches, id: \.self) { hex in
                swatch(hex: hex)
            }
        }
    }

    private func swatch(hex: String) -> some View {
        let isSelected = hex.caseInsensitiveCompare(selectedHex) == .orderedSame

        return Button {
            selectedHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color(hex: hex).opacity(0.4), lineWidth: 3)
                            .padding(-4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Color", comment: "Accessibility: color swatch in the custom category editor"))
        .accessibilityValue(Text(hex))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var selectedHex = DesignSystem.Color.CategoryPalette.housing

    return ColorSwatchPicker(selectedHex: $selectedHex)
        .padding()
}
