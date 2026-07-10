//  Created by Jiri Urbasek on 07/09/26.

import SwiftUI
import SwiftData

/// Full category list presented from the quick picker's "Other…" chip.
/// Owns persistence for newly created custom categories: the pushed
/// `CategoryEditorView` only reports input back via `onCreate`, and this
/// sheet inserts + saves the model, updates the selection, and dismisses
/// itself so the user lands straight back in the bill editor.
struct CategoryPickerSheet: View {
    @Binding var selection: CategoryIdentifier?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AnalyticsModel.self) private var analytics
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var saveErrorMessage: String?

    private var options: [CategoryDisplayInfo] {
        CategoryCatalog.availableCategories(customCategories: customCategories)
    }

    var body: some View {
        NavigationStack {
            List {
                noCategoryRow

                ForEach(options) { option in
                    categoryRow(option)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if option.isCustom {
                                Button(role: .destructive) {
                                    deleteCategory(option)
                                } label: {
                                    Label {
                                        Text("Delete", comment: "Swipe action deleting a custom category")
                                    } icon: {
                                        Image(systemName: "trash")
                                    }
                                }
                                .destructiveTint()
                            }
                        }
                }
            }
            .navigationTitle(Text("Category", comment: "Navigation title of the full category picker"))
            .analyticsScreen(.categoryPicker)
            .platformInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        CategoryEditorView(onCreate: createCategory)
                    } label: {
                        Label {
                            Text("New Category", comment: "Toolbar button opening the custom category editor")
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert(
                Text("Error"),
                isPresented: Binding(isPresent: $saveErrorMessage),
                presenting: saveErrorMessage
            ) { _ in
                Button("OK", role: .cancel) { }
            } message: { message in
                Text(message)
            }
        }
    }

    private var noCategoryRow: some View {
        Button {
            selection = nil
            dismiss()
        } label: {
            HStack {
                Text("No Category", comment: "Row that clears the bill's category")
                    .foregroundStyle(Color.primary)

                Spacer()

                if selection == nil {
                    checkmark
                }
            }
        }
    }

    private func categoryRow(_ option: CategoryDisplayInfo) -> some View {
        Button {
            selection = option.id
            dismiss()
        } label: {
            HStack(spacing: DesignSystem.Spacing.mediumSmall) {
                Image(systemName: option.systemImageName)
                    .foregroundStyle(option.color)
                    .frame(width: 28)

                Text(option.name)
                    .foregroundStyle(Color.primary)

                Spacer()

                if selection == option.id {
                    checkmark
                }
            }
            .replayMaskSensitive()
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
    }

    /// Deletes a custom category. Bills that reference it keep their raw
    /// identifier and degrade gracefully: no category chip in lists, spending
    /// folds into "Other" in charts. Predefined rows never offer this action.
    private func deleteCategory(_ option: CategoryDisplayInfo) {
        guard case .custom(let id) = option.id,
              let category = customCategories.first(where: { $0.id == id }) else { return }

        modelContext.delete(category)

        do {
            try modelContext.save()
            analytics.capture(.customCategoryDeleted)
            if selection == option.id {
                selection = nil
            }
        } catch {
            // Discard the pending deletion so the row doesn't vanish from
            // @Query while remaining persisted.
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
            Logger.log("Failed to delete custom category: \(error)", level: .error)
        }
    }

    private func createCategory(name: String, iconName: String, colorHex: String) {
        let category = CustomCategory(name: name, iconToken: iconName, colorHex: colorHex)
        modelContext.insert(category)

        do {
            try modelContext.save()
            analytics.capture(.customCategoryCreated)
            selection = .custom(category.id)
            dismiss()
        } catch {
            // The main context autosaves — remove the failed insert so it
            // can't linger in @Query results or flush with a later save.
            modelContext.delete(category)
            saveErrorMessage = error.localizedDescription
            Logger.log("Failed to save custom category: \(error)", level: .error)
        }
    }
}

#Preview {
    @Previewable @State var selection: CategoryIdentifier? = .predefined(.housing)
    let preview = BilloPreviewContainer.withSampleData()

    return CategoryPickerSheet(selection: $selection)
        .billoPreviewEnvironment(preview)
}
