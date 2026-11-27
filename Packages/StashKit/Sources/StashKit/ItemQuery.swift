import Foundation

/// What the grid shows, picked in the filter menu.
public enum ItemFilter: Hashable, Sendable {
    case all, readLater, notes
    case collection(StashCollection)

    public var title: String {
        switch self {
        case .all: return "All items"
        case .readLater: return "Read later"
        case .notes: return "Notes"
        case .collection(let c): return c.name
        }
    }

    public func includes(_ item: Item) -> Bool {
        switch self {
        case .all: return true
        case .readLater: return item.isUnread
        case .notes: return item.kind == .note
        case .collection(let c): return item.collection == c
        }
    }
}

public enum SortOrder: String, CaseIterable, Sendable {
    case newest, oldest

    public var title: String { self == .newest ? "Newest first" : "Oldest first" }
}

public enum ItemQuery {
    public static func apply(_ items: [Item], filter: ItemFilter = .all, sort: SortOrder = .newest, search: String = "") -> [Item] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return items
            .filter { filter.includes($0) && (q.isEmpty || matches($0, query: q)) }
            .sorted { sort == .newest ? $0.createdAt > $1.createdAt : $0.createdAt < $1.createdAt }
    }

    /// Search covers title, summary, site, tags, place, notes, checklists and the saved article text.
    public static func matches(_ item: Item, query: String) -> Bool {
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return true }
        let haystack = searchableText(item).lowercased()
        let folded = haystack.folding(options: [.diacriticInsensitive], locale: nil)
        return words.allSatisfy { w in
            haystack.contains(w) || folded.contains(w.folding(options: [.diacriticInsensitive], locale: nil))
        }
    }

    public static func searchableText(_ item: Item) -> String {
        var parts: [String] = [item.title]
        parts.append(item.summary ?? "")
        parts.append(item.siteName ?? "")
        parts.append(item.host ?? "")
        parts.append(item.tags.joined(separator: " "))
        parts.append(item.place.map { [$0.name, $0.address ?? "", $0.city ?? ""].joined(separator: " ") } ?? "")
        parts.append(item.note ?? "")
        parts.append(item.body ?? "")
        parts.append(item.checklist.map(\.text).joined(separator: " "))
        parts.append(item.collection == .none ? "" : item.collection.name)
        parts.append(item.article?.text ?? "")
        return parts.joined(separator: "\n")
    }

    public static func count(_ items: [Item], filter: ItemFilter) -> Int {
        items.filter(filter.includes).count
    }

    public static func unreadCount(_ items: [Item]) -> Int {
        items.filter(\.isUnread).count
    }

    /// Splits cards into the two staggered columns: alternating, with `offset` slots taken by a header in the left column.
    public static func columns<T>(_ list: [T], leadingSlots: Int = 0) -> (left: [T], right: [T]) {
        var left: [T] = []
        var right: [T] = []
        for (i, x) in list.enumerated() {
            if (i + leadingSlots) % 2 == 0 { left.append(x) } else { right.append(x) }
        }
        return (left, right)
    }

    /// Clean, unique tag list (trimmed, case-insensitive duplicates removed).
    public static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { t in
            let s = t.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard !s.isEmpty, seen.insert(s.lowercased()).inserted else { return nil }
            return s
        }
    }
}
