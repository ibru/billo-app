//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI

/// Create-a-custom-category form: name, SF Symbol icon, preset color.
///
/// The editor owns no persistence and never dismisses beyond itself — it
/// validates local input and hands the result to `onCreate`. The presenting
/// `CategoryPickerSheet` inserts the model, updates the selection, and
/// dismisses the whole sheet (a local `dismiss()` here would only pop back
/// to the category list).
struct CategoryEditorView: View {
    let onCreate: (_ name: String, _ iconName: String, _ colorHex: String) -> Void

    @State private var name = ""
    @State private var iconName: String?
    // Default to the first vivid swatch — gray would make a fresh category
    // indistinguishable from the "Other" fallback tone in lists and charts.
    @State private var colorHex = DesignSystem.Color.CategoryPalette.swatches.first
        ?? DesignSystem.Color.CategoryPalette.other

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    CategoryIconButton(selection: $iconName, tint: Color(hex: colorHex))

                    TextField(text: $name) {
                        Text("Category name", comment: "Placeholder for the custom category name field")
                    }
                    .font(.title3)
                    .replayMaskSensitive()
                }
            }

            Section {
                ColorSwatchPicker(selectedHex: $colorHex)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
            } header: {
                Text("Color", comment: "Section header for the custom category color swatches")
            }
        }
        .navigationTitle(Text("New Category", comment: "Navigation title of the custom category editor"))
        .platformInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onCreate(trimmedName, CategoryIcon.resolved(iconName), colorHex)
                } label: {
                    Text("Create", comment: "Confirmation button that creates the custom category")
                }
                .disabled(trimmedName.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryEditorView { _, _, _ in }
    }
}
