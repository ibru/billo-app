//  Created by Jiri Urbasek on 11/27/25.

import Testing
@testable import Billo

@MainActor
@Suite("CategoryCatalog")
struct CategoryCatalogTests {

    @Test
    func whenRequestingAvailableCategories_thenDefaultsAppearBeforeCustoms() {
        let custom = CustomCategory(id: "custom-1", name: "Pets", iconToken: "pawprint", colorToken: "other")

        let available = CategoryCatalog.availableCategories(customCategories: [custom])

        #expect(available.count == DefaultCategoryIdentifier.allCases.count + 1)
        #expect(available.first?.id == .predefined(.utilities))
        #expect(available.last?.id == .custom("custom-1"))
    }

    @Test
    func whenCustomCategoryArchived_thenExcludedFromDefaultPickerResults() {
        let archived = CustomCategory(
            id: "archived",
            name: "Old",
            iconToken: "archivebox",
            colorToken: "other",
            isArchived: true
        )

        let available = CategoryCatalog.availableCategories(customCategories: [archived])

        #expect(available.allSatisfy { $0.id.isDefault })
    }

    @Test
    func whenLookingUpDefaultIdentifier_thenReturnsCatalogMetadata() {
        let info = CategoryCatalog.displayInfo(for: .predefined(.housing), customCategories: [])

        #expect(info?.name == "Housing")
        #expect(info?.iconToken == "housing")
        #expect(info?.colorToken == "housing")
        #expect(info?.isCustom == false)
    }

    @Test
    func whenLookingUpCustomIdentifier_thenReturnsCustomMetadata() {
        let custom = CustomCategory(id: "custom-2", name: "Pets", iconToken: "pawprint", colorToken: "pets")

        let info = CategoryCatalog.displayInfo(for: .custom("custom-2"), customCategories: [custom])

        #expect(info?.name == "Pets")
        #expect(info?.iconToken == "pawprint")
        #expect(info?.colorToken == "pets")
        #expect(info?.isCustom == true)
    }
}
