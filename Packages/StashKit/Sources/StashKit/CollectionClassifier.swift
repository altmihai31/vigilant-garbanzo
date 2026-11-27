import Foundation

/// Sorts an item into Places, Recipes, Reading or Shopping from its structured data, site and words.
public enum CollectionClassifier {
    static let recipeSites = ["seriouseats.com", "bonappetit.com", "allrecipes.com", "cooking.nytimes.com", "epicurious.com",
                              "foodnetwork.com", "bbcgoodfood.com", "simplyrecipes.com", "food52.com", "delish.com", "tasty.co",
                              "budgetbytes.com", "smittenkitchen.com", "jamieoliver.com", "kingarthurbaking.com", "thekitchn.com"]
    static let placeSites = ["cntraveler.com", "timeout.com", "eater.com", "tripadvisor.com", "booking.com", "airbnb.com",
                             "lonelyplanet.com", "maps.apple.com", "yelp.com", "guide.michelin.com", "afar.com",
                             "travelandleisure.com", "atlasobscura.com", "theinfatuation.com", "hotels.com", "expedia.com"]
    static let shoppingSites = ["amazon.com", "amazon.co.uk", "amazon.de", "ebay.com", "etsy.com", "bestbuy.com", "ikea.com",
                                "emag.ro", "zara.com", "hm.com", "aliexpress.com", "target.com", "walmart.com", "store.apple.com",
                                "wirecutter.com", "rtings.com"]

    static let recipeWords = ["recipe", "recipes", "ingredients", "tablespoon", "tablespoons", "teaspoon", "teaspoons",
                              "bake", "baked", "roast", "roasted", "simmer", "serves", "pasta", "spaghetti", "gnocchi",
                              "dinner", "weeknight", "sheet pan", "sheet-pan", "oven", "skillet", "dessert", "soup", "salad",
                              "cook", "cooking", "sauce", "minutes to make", "prep time"]
    static let placeWords = ["hotel", "hotels", "restaurant", "restaurants", "where to eat", "where to stay", "trail",
                             "trails", "hike", "hikes", "hiking", "travel", "city guide", "things to do", "itinerary", "resort",
                             "resorts", "cafe", "cafes", "bars", "beach", "beaches", "visit", "visitors", "visiting",
                             "sushi spots", "spots", "neighborhood", "neighbourhood", "coast", "island", "airport",
                             "museum", "weekend in", "day trip", "road trip"]
    static let shoppingWords = ["review", "reviews", "buy", "buying", "deal", "deals", "sale", "price", "discount", "coupon",
                                "gift", "gifts", "wishlist", "wish list", "shopping", "groceries", "grocery", "best headphones",
                                "in stock", "order", "unboxing", "vs", "hands on", "hands-on", "best budget"]

    public static func classify(kind: ItemKind = .link, url: URL?, title: String, text: String = "",
                                schemaTypes: [String] = [], hasPlace: Bool = false) -> StashCollection {
        if kind == .note {
            let t = normalized(title + " " + text.prefix(400))
            return ["gift", "gifts", "buy", "shopping", "groceries", "grocery", "wishlist", "wish list"]
                .contains(where: { t.contains(" \($0) ") }) ? .shopping : .none
        }
        let types = Set(schemaTypes.map { $0.lowercased() })
        if types.contains("recipe") { return .recipes }
        if !types.isDisjoint(with: ["product", "productgroup", "offer", "aggregateoffer", "og:product", "product.item"]) { return .shopping }
        if hasPlace || !types.isDisjoint(with: PageMetadataParser.placeTypes) { return .places }

        let host = (url?.host ?? "").lowercased()
        func on(_ sites: [String]) -> Bool { sites.contains { host == $0 || host.hasSuffix("." + $0) } }
        var scores: [StashCollection: Int] = [.recipes: 0, .places: 0, .shopping: 0]
        if on(recipeSites) { scores[.recipes, default: 0] += 4 }
        if on(placeSites) { scores[.places, default: 0] += 4 }
        if on(shoppingSites) { scores[.shopping, default: 0] += 4 }
        if (url?.path ?? "").lowercased().contains("/recipe") { scores[.recipes, default: 0] += 3 }

        let t = normalized(title)
        let body = normalized(String(text.prefix(3000)))
        for (collection, words) in [(StashCollection.recipes, recipeWords), (.places, placeWords), (.shopping, shoppingWords)] {
            for w in words {
                if t.contains(" \(w) ") { scores[collection, default: 0] += 3 }
                if body.contains(" \(w) ") { scores[collection, default: 0] += 1 }
            }
        }
        let best = scores.max { a, b in a.value == b.value ? a.key.rawValue > b.key.rawValue : a.value < b.value }!
        return best.value >= 3 ? best.key : .reading
    }

    /// Lowercase, punctuation turned into spaces, padded so `" word "` matches whole words.
    static func normalized(_ s: String) -> String {
        let mapped = s.lowercased().map { ch -> Character in
            ch.isLetter || ch.isNumber || ch == "-" ? ch : " "
        }
        return " " + String(mapped).split(separator: " ").joined(separator: " ") + " "
    }
}
