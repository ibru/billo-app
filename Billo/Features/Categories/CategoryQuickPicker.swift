//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI

/// Bill editor's category control. Renders like a standard form picker row;
/// the menu offers "None" + the 8 most-used categories, and — separated by a
/// divider — a "More…" action opening the full catalog sheet where new
/// custom categories can also be created.
///
/// Implemented as `Menu` + inline `Picker` because a plain `Picker` cannot
/// host action items like "More…" among its options.
struct CategoryQuickPicker: View {
    @Binding var selection: CategoryIdentifier?
    let usageCounts: [CategoryIdentifier: Int]
    let customCategories: [CustomCategory]

    @Environment(AnalyticsModel.self) private var analytics
    @State private var showsFullPicker = false

    private var quickPicks: [CategoryDisplayInfo] {
        CategoryCatalog.quickPickCategories(
            customCategories: customCategories,
            usageCounts: usageCounts,
            selected: selection
        )
    }

    private var selectedDisplay: CategoryDisplayInfo? {
        guard let selection else { return nil }
        return CategoryCatalog.displayInfo(for: selection, customCategories: customCategories)
    }

    var body: some View {
        Menu {
            Picker("Category", selection: $selection) {
                Text("None").tag(nil as CategoryIdentifier?)
                ForEach(quickPicks) { option in
                    HStack {
                        menuIcon(for: option)
                        Text(option.name)
                    }
                    .tag(option.id as CategoryIdentifier?)
                }
            }

            Divider()

            Button {
                showsFullPicker = true
            } label: {
                Label {
                    Text("More…", comment: "Menu item opening the full category list")
                } icon: {
                    Image(systemName: "square.grid.2x2")
                }
            }
        } label: {
            HStack {
                Text("Category")
                    .foregroundStyle(Color.primary)

                Spacer()

                if let selectedDisplay {
                    Image(systemName: selectedDisplay.systemImageName)
                        .foregroundStyle(selectedDisplay.color)
                    Text(selectedDisplay.name)
                        .replayMaskSensitive()
                } else {
                    Text("None")
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.medium))
            }
        }
        .accessibilityHint(Text("Selects a category. More… shows all categories", comment: "Accessibility hint for the category picker row"))
        .sheet(isPresented: $showsFullPicker) {
            CategoryPickerSheet(selection: $selection)
                // Mac Catalyst drops @Observable environment values at the
                // sheet boundary (see AppEnvironmentModels) — re-inject the
                // one model the picker sheet reads.
                .environment(analytics)
        }
        .onAppear {
            // A bill can reference a custom category that was deleted since.
            // The row would show "None" while silently re-saving the dangling
            // id — make the UI honest by actually clearing the selection.
            if selection != nil, selectedDisplay == nil {
                selection = nil
            }
        }
    }

    /// Menus render template images in the tint color, discarding any
    /// `foregroundStyle` — a pre-tinted `.alwaysOriginal` UIImage is the
    /// only way to keep per-category colors inside menu rows.
    private func menuIcon(for option: CategoryDisplayInfo) -> Image {
        if let uiImage = UIImage(systemName: option.systemImageName)?
            .withTintColor(UIColor(option.color), renderingMode: .alwaysOriginal) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: option.systemImageName)
    }
}

#Preview {
    @Previewable @State var selection: CategoryIdentifier? = .predefined(.housing)

    return Form {
        Section("Basic Information") {
            CategoryQuickPicker(
                selection: $selection,
                usageCounts: [.predefined(.utilities): 3, .predefined(.pets): 2],
                customCategories: []
            )
        }
    }
    .environment(AnalyticsModel())
}
