import Foundation

/// Pure, on-device combinatorial Gap Finder (spec §5.4). Builds a pairwise compatibility matrix
/// over the wardrobe, counts the valid outfits it can form, then for each candidate "missing item"
/// archetype simulates how many *new* valid outfits it would unlock — ranking the highest-impact gaps.
///
/// A valid outfit is `top + bottom + shoes` (all pairwise compatible) or `dress + shoes`.
/// Compatibility uses formality proximity and pattern non-clash (color is treated permissively —
/// see TRADEOFFS). Outerwear/accessories are not gap candidates in this version.
enum CombinationMatrix {

    /// Two items are compatible if their formality is within one rank and patterns don't clash.
    static func compatible(_ a: ClothingItem, _ b: ClothingItem) -> Bool {
        guard abs(a.formality.rank - b.formality.rank) <= 1 else { return false }
        // Pattern clash: two different non-solid patterns.
        if a.pattern != .solid && b.pattern != .solid && a.pattern != b.pattern { return false }
        return true
    }

    /// Number of valid outfits formable from `items`.
    static func validOutfitCount(_ items: [ClothingItem]) -> Int {
        let tops = items.filter { $0.category == .top }
        let bottoms = items.filter { $0.category == .bottom }
        let shoes = items.filter { $0.category == .shoes }
        let dresses = items.filter { $0.category == .dress }

        var count = 0
        for top in tops {
            for bottom in bottoms where compatible(top, bottom) {
                if shoes.isEmpty {
                    count += 1   // top+bottom counts even before shoes exist
                } else {
                    count += shoes.filter { compatible(top, $0) && compatible(bottom, $0) }.count
                }
            }
        }
        for dress in dresses {
            count += shoes.isEmpty ? 1 : shoes.filter { compatible(dress, $0) }.count
        }
        return count
    }

    /// Curated archetype items used as "what if I owned this?" candidates.
    static var archetypes: [GapCandidate] {
        [
            GapCandidate(category: .top, description: "A crisp white button-down shirt",
                         formality: .smartCasual, colors: ["#FFFFFF"], newOutfitsUnlocked: 0),
            GapCandidate(category: .top, description: "A grey crewneck tee",
                         formality: .casual, colors: ["#9A9A9A"], newOutfitsUnlocked: 0),
            GapCandidate(category: .bottom, description: "A pair of navy chinos",
                         formality: .smartCasual, colors: ["#1F2D5A"], newOutfitsUnlocked: 0),
            GapCandidate(category: .bottom, description: "Dark wash jeans",
                         formality: .casual, colors: ["#2A3F5F"], newOutfitsUnlocked: 0),
            GapCandidate(category: .bottom, description: "Tailored black trousers",
                         formality: .business, colors: ["#1A1A1A"], newOutfitsUnlocked: 0),
            GapCandidate(category: .shoes, description: "White leather sneakers",
                         formality: .casual, colors: ["#FFFFFF"], newOutfitsUnlocked: 0),
            GapCandidate(category: .shoes, description: "Brown leather loafers",
                         formality: .smartCasual, colors: ["#5A3A22"], newOutfitsUnlocked: 0),
            GapCandidate(category: .dress, description: "A little black dress",
                         formality: .business, colors: ["#1A1A1A"], newOutfitsUnlocked: 0)
        ]
    }

    /// Ranks the archetypes by how many new valid outfits each would unlock for `wardrobe`.
    /// Returns only positive-impact candidates, highest first.
    static func analyze(_ wardrobe: [ClothingItem], maxResults: Int = 5) -> [GapCandidate] {
        let base = validOutfitCount(wardrobe)
        let scored: [GapCandidate] = archetypes.map { archetype in
            let item = ClothingItem(
                name: archetype.description,
                category: archetype.category,
                color: archetype.colors,
                pattern: .solid,
                formality: archetype.formality
            )
            var candidate = archetype
            candidate.newOutfitsUnlocked = validOutfitCount(wardrobe + [item]) - base
            return candidate
        }
        return scored
            .filter { $0.newOutfitsUnlocked > 0 }
            .sorted { $0.newOutfitsUnlocked > $1.newOutfitsUnlocked }
            .prefix(maxResults)
            .map { $0 }
    }
}
