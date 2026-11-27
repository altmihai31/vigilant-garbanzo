import Foundation

/// A saved link or a note.
public enum ItemKind: String, Codable, Sendable, CaseIterable {
    case link, note
}

/// The four automatic collections. `none` means the item is not in any of them.
public enum StashCollection: String, Codable, Sendable, CaseIterable, Identifiable {
    case places, recipes, reading, shopping, none

    public var id: String { rawValue }

    /// The collections shown in the filter menu, in menu order.
    public static let visible: [StashCollection] = [.places, .recipes, .reading, .shopping]

    public var name: String {
        switch self {
        case .places: return "Places"
        case .recipes: return "Recipes"
        case .reading: return "Reading"
        case .shopping: return "Shopping"
        case .none: return "No collection"
        }
    }

    /// SF Symbol for menus, chips and the card corner icon.
    public var symbol: String {
        switch self {
        case .places: return "mappin"
        case .recipes: return "fork.knife"
        case .reading: return "book"
        case .shopping: return "bag"
        case .none: return "tray"
        }
    }
}

public enum SummarySource: String, Codable, Sendable {
    case onDevice, pageDescription, none
}

public enum ProcessingState: String, Codable, Sendable {
    case pending, done, failed
}

public struct ChecklistItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var done: Bool

    public init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}

public struct Place: Codable, Hashable, Sendable {
    public var name: String
    public var address: String?
    public var city: String?
    public var latitude: Double?
    public var longitude: Double?

    public init(name: String, address: String? = nil, city: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.address = address
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
    }

    public var hasCoordinate: Bool { latitude != nil && longitude != nil }

    /// Text handed to the map search and to Apple Maps.
    public var searchQuery: String {
        [name, address].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Apple Maps link: pin at the coordinate when known, otherwise a search.
    public var mapsURL: URL {
        var c = URLComponents(string: "https://maps.apple.com/")!
        var q = [URLQueryItem(name: "q", value: name)]
        if let lat = latitude, let lon = longitude {
            q.append(URLQueryItem(name: "ll", value: "\(lat),\(lon)"))
        } else if let a = address, !a.isEmpty {
            q = [URLQueryItem(name: "q", value: searchQuery)]
        }
        c.queryItems = q
        return c.url!
    }
}

/// The readable copy of an article, kept for offline reading.
public struct Article: Codable, Hashable, Sendable {
    public var paragraphs: [String]
    public var savedAt: Date
    public var readingMinutes: Int

    public init(paragraphs: [String], savedAt: Date, readingMinutes: Int? = nil) {
        self.paragraphs = paragraphs
        self.savedAt = savedAt
        self.readingMinutes = readingMinutes ?? ArticleExtractor.readingMinutes(for: paragraphs)
    }

    public var text: String { paragraphs.joined(separator: "\n\n") }
}

public struct Item: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ItemKind
    public var createdAt: Date
    public var title: String
    public var summary: String?
    public var summarySource: SummarySource
    public var url: URL?
    public var siteName: String?
    /// File name inside the store's Images folder.
    public var imageFileName: String?
    public var body: String?
    public var checklist: [ChecklistItem]
    public var collection: StashCollection
    public var collectionIsManual: Bool
    public var tags: [String]
    public var isUnread: Bool
    public var remindAt: Date?
    public var place: Place?
    public var article: Article?
    public var note: String?
    public var processingState: ProcessingState
    /// Demo-only artwork name used instead of a downloaded image.
    public var demoArt: String?

    public init(id: UUID = UUID(), kind: ItemKind, createdAt: Date = Date(), title: String, summary: String? = nil,
                summarySource: SummarySource = .none, url: URL? = nil, siteName: String? = nil, imageFileName: String? = nil,
                body: String? = nil, checklist: [ChecklistItem] = [], collection: StashCollection = .none,
                collectionIsManual: Bool = false, tags: [String] = [], isUnread: Bool = false, remindAt: Date? = nil,
                place: Place? = nil, article: Article? = nil, note: String? = nil,
                processingState: ProcessingState = .done, demoArt: String? = nil) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.title = title
        self.summary = summary
        self.summarySource = summarySource
        self.url = url
        self.siteName = siteName
        self.imageFileName = imageFileName
        self.body = body
        self.checklist = checklist
        self.collection = collection
        self.collectionIsManual = collectionIsManual
        self.tags = tags
        self.isUnread = isUnread
        self.remindAt = remindAt
        self.place = place
        self.article = article
        self.note = note
        self.processingState = processingState
        self.demoArt = demoArt
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, createdAt, title, summary, summarySource, url, siteName, imageFileName, body, checklist
        case collection, collectionIsManual, tags, isUnread, remindAt, place, article, note, processingState, demoArt
    }

    /// Lenient decoding so files written by older builds still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(ItemKind.self, forKey: .kind) ?? .link
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        summarySource = (try? c.decodeIfPresent(SummarySource.self, forKey: .summarySource)) ?? SummarySource.none
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        siteName = try c.decodeIfPresent(String.self, forKey: .siteName)
        imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        checklist = try c.decodeIfPresent([ChecklistItem].self, forKey: .checklist) ?? []
        collection = (try? c.decodeIfPresent(StashCollection.self, forKey: .collection)) ?? StashCollection.none
        collectionIsManual = try c.decodeIfPresent(Bool.self, forKey: .collectionIsManual) ?? false
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        isUnread = try c.decodeIfPresent(Bool.self, forKey: .isUnread) ?? false
        remindAt = try c.decodeIfPresent(Date.self, forKey: .remindAt)
        place = try c.decodeIfPresent(Place.self, forKey: .place)
        article = try c.decodeIfPresent(Article.self, forKey: .article)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        processingState = (try? c.decodeIfPresent(ProcessingState.self, forKey: .processingState)) ?? .done
        demoArt = try c.decodeIfPresent(String.self, forKey: .demoArt)
    }

    /// Host without "www.", used when the page has no site name.
    public var host: String? {
        guard let h = url?.host?.lowercased() else { return nil }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    /// The site line on cards: the host, like the mockup ("cntraveler.com").
    public var siteLabel: String { host ?? siteName ?? "" }

    /// A reminder that has not fired yet.
    public func hasUpcomingReminder(now: Date = Date()) -> Bool {
        guard let r = remindAt else { return false }
        return r > now
    }

    /// Marks the item read and drops its reminder.
    public mutating func markRead() {
        isUnread = false
        remindAt = nil
    }
}
