import Testing
@testable import WorstAdvice

// MARK: - Advice Bank Tests

@Suite("Advice Bank")
struct AdviceBankTests {

    @Test("All advice entries have non-empty text")
    func allAdviceHasText() {
        for advice in AdviceBank.all {
            #expect(!advice.text.isEmpty, "Advice ID \(advice.id) has empty text")
        }
    }

    @Test("Every category has at least one piece of advice")
    func everyCategoryRepresented() {
        let categories = AdviceCategory.allCases
        for category in categories {
            let count = AdviceBank.all.filter { $0.category == category }.count
            #expect(count > 0, "Category \(category.rawValue) has no advice")
        }
    }

    @Test("Random advice returns a valid entry")
    func randomAdviceIsValid() {
        let advice = AdviceBank.random()
        #expect(AdviceBank.all.contains(advice))
    }

    @Test("Random advice excludes the current advice when possible")
    func randomAdviceExcludesCurrent() {
        let current = AdviceBank.all[0]
        var seenSame = false
        // Run many times to confirm exclusion holds
        for _ in 0..<50 {
            let next = AdviceBank.random(excluding: current)
            if next.id == current.id {
                seenSame = true
                break
            }
        }
        #expect(!seenSame, "random(excluding:) returned the excluded advice")
    }

    @Test("Random advice for a specific category stays in category")
    func randomAdviceRespectsCategory() {
        for category in AdviceCategory.allCases {
            let advice = AdviceBank.random(for: category)
            #expect(advice.category == category)
        }
    }

    @Test("All advice IDs are unique")
    func adviceIDsAreUnique() {
        let ids = AdviceBank.all.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count, "Duplicate IDs found in AdviceBank")
    }
}

// MARK: - AdviceCategory Tests

@Suite("AdviceCategory")
struct AdviceCategoryTests {

    @Test("All categories have a non-empty emoji")
    func categoriesHaveEmojis() {
        for category in AdviceCategory.allCases {
            #expect(!category.emoji.isEmpty)
        }
    }

    @Test("All categories have a non-empty color name")
    func categoriesHaveColors() {
        for category in AdviceCategory.allCases {
            #expect(!category.color.isEmpty)
        }
    }

    @Test("Category IDs are unique")
    func categoryIDsAreUnique() {
        let ids = AdviceCategory.allCases.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

// MARK: - AdviceViewModel Tests

@Suite("AdviceViewModel")
struct AdviceViewModelTests {

    @Test("ViewModel initialises with a valid advice")
    func initialAdviceIsValid() {
        let vm = AdviceViewModel()
        #expect(AdviceBank.all.contains(vm.currentAdvice))
    }

    @Test("Deal count starts at zero")
    func dealCountStartsAtZero() {
        let vm = AdviceViewModel()
        #expect(vm.dealCount == 0)
    }

    @Test("Deal count increments on each deal")
    func dealCountIncrements() {
        let vm = AdviceViewModel()
        vm.dealNewAdvice()
        #expect(vm.dealCount == 1)
        vm.dealNewAdvice()
        #expect(vm.dealCount == 2)
    }

    @Test("New advice is dealt on dealNewAdvice")
    func dealNewAdviceChangesAdvice() throws {
        let vm = AdviceViewModel()
        // Because the bank has >1 entry, the new advice should differ
        var changed = false
        for _ in 0..<20 {
            let before = vm.currentAdvice
            vm.dealNewAdvice()
            if vm.currentAdvice.id != before.id {
                changed = true
                break
            }
        }
        #expect(changed, "Advice never changed after 20 deals")
    }

    @Test("Toggling favourite adds advice to favourites")
    func toggleFavouriteAdds() {
        let vm = AdviceViewModel()
        #expect(!vm.isFavorited)
        vm.toggleFavorite()
        #expect(vm.isFavorited)
        #expect(vm.favorites.contains(vm.currentAdvice))
    }

    @Test("Toggling favourite twice removes advice from favourites")
    func toggleFavouriteTwiceRemoves() {
        let vm = AdviceViewModel()
        vm.toggleFavorite()
        vm.toggleFavorite()
        #expect(!vm.isFavorited)
        #expect(!vm.favorites.contains(vm.currentAdvice))
    }

    @Test("Selecting a category filters advice to that category")
    func categoryFilterApplied() {
        let vm = AdviceViewModel()
        vm.selectedCategory = .tech
        for _ in 0..<20 {
            vm.dealNewAdvice()
            #expect(vm.currentAdvice.category == .tech)
        }
    }

    @Test("Clearing the category filter allows all categories")
    func clearingCategoryFilterAllowsAll() {
        let vm = AdviceViewModel()
        vm.selectedCategory = .tech
        vm.dealNewAdvice()
        vm.selectedCategory = nil

        var seenNonTech = false
        for _ in 0..<50 {
            vm.dealNewAdvice()
            if vm.currentAdvice.category != .tech {
                seenNonTech = true
                break
            }
        }
        #expect(seenNonTech, "After clearing the filter, only tech advice was returned")
    }

    @Test("Favorites list is empty on init")
    func favoritesEmptyOnInit() {
        let vm = AdviceViewModel()
        #expect(vm.favorites.isEmpty)
    }

    @Test("Multiple unique pieces of advice can be favourited")
    func multipleFavorites() throws {
        let vm = AdviceViewModel()
        var favorited = 0
        var seen = Set<UUID>()

        repeat {
            if !seen.contains(vm.currentAdvice.id) {
                vm.toggleFavorite()
                seen.insert(vm.currentAdvice.id)
                favorited += 1
            }
            vm.dealNewAdvice()
        } while favorited < 3

        #expect(vm.favorites.count == 3)
    }
}
