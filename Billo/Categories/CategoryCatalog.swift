//  Created by Jiri Urbasek on 11/27/25.

import Foundation

struct CategoryDefinition: Identifiable, Sendable {
    let identifier: DefaultCategoryIdentifier
    let name: String
    let iconToken: String
    let colorToken: String
    let sortOrder: Int

    var id: DefaultCategoryIdentifier { identifier }

    var categoryIdentifier: CategoryIdentifier { .predefined(identifier) }
}

struct CategoryDisplayInfo: Identifiable, Hashable, Sendable {
    let id: CategoryIdentifier
    let name: String
    let iconToken: String
    let colorToken: String
    let isArchived: Bool
    let isCustom: Bool
    let sortOrder: Int
}

enum CategoryCatalog {
    static let currentVersion = "2025.1"

    private static var cachedDefaults: [CategoryIdentifier: CategoryDisplayInfo] = [:]
    private static let cacheLock = NSLock()

    static func availableCategories(
        customCategories: [CustomCategory],
        includeArchived: Bool = false
    ) -> [CategoryDisplayInfo] {
        CategoryCatalogVersioning.ensureCurrentVersionApplied()

        let defaults = definitions.map { definition in
            cachedDefaultDisplayInfo(for: definition)
        }

        let customInfos = customCategories.enumerated().compactMap { pair -> CategoryDisplayInfo? in
            let (index, category) = pair
            guard includeArchived || category.isArchived == false else { return nil }
            return CategoryDisplayInfo(
                id: .custom(category.id),
                name: category.name,
                iconToken: category.iconToken,
                colorToken: category.colorToken,
                isArchived: category.isArchived,
                isCustom: true,
                sortOrder: definitionSortBase + index
            )
        }

        return (defaults + customInfos)
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    static func displayInfo(
        for identifier: CategoryIdentifier?,
        customCategories: [CustomCategory]
    ) -> CategoryDisplayInfo? {
        guard let identifier else { return nil }
        CategoryCatalogVersioning.ensureCurrentVersionApplied()

        switch identifier {
        case .predefined(let defaultIdentifier):
            guard let definition = definitionsMap[defaultIdentifier] else { return nil }
            return cachedDefaultDisplayInfo(for: definition)
        case .custom(let id):
            guard let index = customCategories.firstIndex(where: { $0.id == id }) else { return nil }
            let category = customCategories[index]
            return CategoryDisplayInfo(
                id: .custom(category.id),
                name: category.name,
                iconToken: category.iconToken,
                colorToken: category.colorToken,
                isArchived: category.isArchived,
                isCustom: true,
                sortOrder: definitionSortBase + index
            )
        }
    }

    static func invalidateCaches() {
        cacheLock.lock()
        cachedDefaults.removeAll()
        cacheLock.unlock()
    }

    private static func cachedDefaultDisplayInfo(for definition: CategoryDefinition) -> CategoryDisplayInfo {
        cacheLock.perform {
            if let cached = cachedDefaults[definition.categoryIdentifier] {
                return cached
            }

            let displayInfo = CategoryDisplayInfo(
                id: definition.categoryIdentifier,
                name: definition.name,
                iconToken: definition.iconToken,
                colorToken: definition.colorToken,
                isArchived: false,
                isCustom: false,
                sortOrder: definition.sortOrder
            )

            cachedDefaults[definition.categoryIdentifier] = displayInfo
            return displayInfo
        }
    }

    private static let definitions: [CategoryDefinition] = DefaultCategoryIdentifier.allCases.map { identifier in
        CategoryDefinition(
            identifier: identifier,
            name: identifier.displayName,
            iconToken: identifier.iconToken,
            colorToken: identifier.colorToken,
            sortOrder: identifier.sortOrder
        )
    }

    private static let definitionsMap: [DefaultCategoryIdentifier: CategoryDefinition] = {
        var map: [DefaultCategoryIdentifier: CategoryDefinition] = [:]
        for definition in definitions {
            map[definition.identifier] = definition
        }
        return map
    }()

    private static let definitionSortBase = 1000
}

enum CategoryCatalogVersioning {
    private static let defaultsKey = "CategoryCatalogVersion"

    static func ensureCurrentVersionApplied() {
        let defaults = UserDefaults.standard
        let appliedVersion = defaults.string(forKey: defaultsKey)
        guard appliedVersion != CategoryCatalog.currentVersion else { return }

        CategoryCatalog.invalidateCaches()
        defaults.set(CategoryCatalog.currentVersion, forKey: defaultsKey)
    }
}

private extension NSLock {
    func perform<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}
