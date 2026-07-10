//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI
import SFSymbols

/// Default icon fallback when a custom category has no picked symbol yet.
enum CategoryIcon {
    static let defaultSymbol = "tag"

    static func resolved(_ symbol: String?) -> String {
        guard let symbol, !symbol.isEmpty else { return defaultSymbol }
        return symbol
    }
}

/// Tappable rounded-rect tile rendering the chosen category icon with a
/// pencil-badge overlay. Presents the system-wide SF Symbols catalog via
/// the `SFSymbols` package (full search/categorised browser).
struct CategoryIconButton: View {
    @Binding var selection: String?
    var tint: Color = .accentColor
    var size: CGFloat = 56
    @State private var showingPicker = false

    private var hasIcon: Bool {
        guard let selection else { return false }
        return !selection.isEmpty
    }

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            tile
        }
        .buttonStyle(.plain)
        .sfSymbolPicker(isPresented: $showingPicker, selection: $selection)
        .accessibilityLabel(Text("Category icon", comment: "Accessibility: icon tile in the custom category editor"))
        .accessibilityValue(
            selection.map { Text($0) }
                ?? Text("Not set", comment: "Accessibility: no icon selected yet")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Opens icon picker", comment: "Accessibility hint for the category icon tile"))
    }

    private var tile: some View {
        Image(systemName: CategoryIcon.resolved(selection))
            .font(.title2)
            .foregroundStyle(tint.opacity(hasIcon ? 1 : 0.4))
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(tint.opacity(hasIcon ? 0.12 : 0.06))
            }
            .overlay(alignment: .bottomTrailing) {
                pencilBadge.offset(x: 4, y: 4)
            }
    }

    private var pencilBadge: some View {
        Image(systemName: "pencil")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(5)
            .background(Circle().fill(tint))
    }
}

#Preview {
    @Previewable @State var selection: String? = nil

    return CategoryIconButton(selection: $selection)
        .padding()
}
