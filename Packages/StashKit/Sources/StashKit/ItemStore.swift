import Foundation

/// A save handed over by the Share Extension. The main app turns it into an `Item` and finishes the work.
public struct InboxEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var url: URL
    public var title: String?
    public var summary: String?
    public var siteName: String?
    public var imageFileName: String?
    public var collection: StashCollection?
    public var remindAt: Date?
    public var note: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), url: URL, title: String? = nil, summary: String? = nil, siteName: String? = nil,
                imageFileName: String? = nil, collection: StashCollection? = nil, remindAt: Date? = nil,
                note: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.summary = summary
        self.siteName = siteName
        self.imageFileName = imageFileName
        self.collection = collection
        self.remindAt = remindAt
        self.note = note
        self.createdAt = createdAt
    }

    /// A pending link item; the app fetches the page, summary and offline copy afterwards.
    public func makeItem() -> Item {
        Item(id: id, kind: .link, createdAt: createdAt, title: title?.isEmpty == false ? title! : (url.host ?? url.absoluteString),
             summary: summary, summarySource: summary == nil ? .none : .pageDescription, url: url, siteName: siteName,
             imageFileName: imageFileName, collection: collection ?? .none, isUnread: remindAt != nil, remindAt: remindAt,
             note: note, processingState: .pending)
    }
}

public enum ItemMerge {
    /// Adds inbox saves to the list. Saving a URL that is already in Stash moves it to the top instead of duplicating it.
    public static func merge(_ entries: [InboxEntry], into items: [Item]) -> [Item] {
        var result = items
        for e in entries.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let i = result.firstIndex(where: { $0.url.map(canonical) == canonical(e.url) }) {
                result[i].createdAt = e.createdAt
                if let r = e.remindAt { result[i].remindAt = r; result[i].isUnread = true }
                if let n = e.note, !n.isEmpty { result[i].note = n }
            } else {
                result.append(e.makeItem())
            }
        }
        return result
    }

    /// URL identity ignoring scheme, "www.", fragments and a trailing slash.
    public static func canonical(_ url: URL) -> String {
        var host = (url.host ?? "").lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }
        var path = url.path
        if path.hasSuffix("/") { path.removeLast() }
        let query = url.query.map { "?" + $0 } ?? ""
        return host + path + query
    }
}

/// JSON file store. The app writes `items.json`; the Share Extension only drops files in `Inbox/`,
/// so the two processes never write the same file.
public final class ItemStore: @unchecked Sendable {
    public let directory: URL
    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "stash.store")

    public init(directory: URL) {
        self.directory = directory
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: inboxDirectory, withIntermediateDirectories: true)
    }

    public var itemsURL: URL { directory.appendingPathComponent("items.json") }
    public var imagesDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }
    public var inboxDirectory: URL { directory.appendingPathComponent("Inbox", isDirectory: true) }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    public func load() -> [Item] {
        queue.sync {
            guard let data = try? Data(contentsOf: itemsURL) else { return [] }
            return (try? Self.decoder.decode([Item].self, from: data)) ?? []
        }
    }

    public func save(_ items: [Item]) throws {
        let data = try Self.encoder.encode(items)
        try queue.sync { try data.write(to: itemsURL, options: .atomic) }
    }

    // MARK: Images

    public func imageURL(named name: String) -> URL { imagesDirectory.appendingPathComponent(name) }

    @discardableResult
    public func writeImage(_ data: Data, for id: UUID, ext: String = "jpg") throws -> String {
        let name = "\(id.uuidString).\(ext)"
        try data.write(to: imageURL(named: name), options: .atomic)
        return name
    }

    public func deleteImage(named name: String?) {
        guard let name else { return }
        try? fm.removeItem(at: imageURL(named: name))
    }

    // MARK: Inbox

    public func enqueue(_ entry: InboxEntry) throws {
        let data = try Self.encoder.encode(entry)
        try data.write(to: inboxDirectory.appendingPathComponent("\(entry.id.uuidString).json"), options: .atomic)
    }

    /// Reads and removes every pending inbox entry.
    public func drainInbox() -> [InboxEntry] {
        queue.sync {
            guard let files = try? fm.contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil) else { return [] }
            var out: [InboxEntry] = []
            for f in files where f.pathExtension == "json" {
                if let data = try? Data(contentsOf: f), let e = try? Self.decoder.decode(InboxEntry.self, from: data) {
                    out.append(e)
                }
                try? fm.removeItem(at: f)
            }
            return out.sorted { $0.createdAt < $1.createdAt }
        }
    }
}

/// App Group and URL scheme shared by the app and the Share Extension.
public enum StashShared {
    public static let defaultAppGroup = "group.com.altmihai31.stash"
    public static let urlScheme = "stash"

    /// App Group ids to try: the one in Info.plist (`StashAppGroup`), any that a sideloading tool rewrote
    /// (`ALTAppGroups`), then the default.
    public static func appGroupCandidates(bundle: Bundle = .main) -> [String] {
        var ids: [String] = []
        if let s = bundle.object(forInfoDictionaryKey: "StashAppGroup") as? String { ids.append(s) }
        if let a = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { ids.append(contentsOf: a) }
        ids.append(defaultAppGroup)
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// The shared container, if the App Group entitlement survived signing and is writable.
    public static func sharedContainer(bundle: Bundle = .main) -> URL? {
        #if canImport(Darwin)
        let fm = FileManager.default
        for id in appGroupCandidates(bundle: bundle) {
            guard let url = fm.containerURL(forSecurityApplicationGroupIdentifier: id) else { continue }
            let dir = url.appendingPathComponent("Stash", isDirectory: true)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                let probe = dir.appendingPathComponent(".probe")
                try Data().write(to: probe)
                try? fm.removeItem(at: probe)
                return dir
            } catch {
                continue
            }
        }
        #endif
        return nil
    }

    /// `stash://save?...` hands a save to the app when there is no shared container.
    public static func saveURL(for e: InboxEntry) -> URL {
        var c = URLComponents()
        c.scheme = urlScheme
        c.host = "save"
        var q = [URLQueryItem(name: "url", value: e.url.absoluteString)]
        if let t = e.title { q.append(URLQueryItem(name: "title", value: t)) }
        if let s = e.summary { q.append(URLQueryItem(name: "summary", value: s)) }
        if let r = e.remindAt { q.append(URLQueryItem(name: "remind", value: String(Int(r.timeIntervalSince1970)))) }
        if let col = e.collection { q.append(URLQueryItem(name: "collection", value: col.rawValue)) }
        c.queryItems = q
        return c.url!
    }

    /// `stash://item/<uuid>` opens an item (used by reminder notifications).
    public static func itemURL(_ id: UUID) -> URL {
        URL(string: "\(urlScheme)://item/\(id.uuidString)")!
    }

    public enum Link: Equatable {
        case save(InboxEntry)
        case item(UUID)
    }

    public static func parse(_ url: URL, now: Date = Date()) -> Link? {
        guard url.scheme == urlScheme, let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        switch url.host {
        case "item":
            let id = url.pathComponents.dropFirst().first ?? ""
            return UUID(uuidString: id).map { .item($0) }
        case "save":
            let q = Dictionary((c.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
            guard let s = q["url"], let u = URL(string: s), u.scheme?.hasPrefix("http") == true else { return nil }
            let remind = q["remind"].flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }
            return .save(InboxEntry(url: u, title: q["title"], summary: q["summary"],
                                    collection: q["collection"].flatMap(StashCollection.init(rawValue:)),
                                    remindAt: remind, createdAt: now))
        default:
            return nil
        }
    }

    /// The first web URL in shared text (YouTube and some apps share text, not a URL).
    public static func firstURL(in text: String) -> URL? {
        let pattern = "https?://[^\\s<>\"]+"
        guard let m = HTMLText.matches(pattern, in: text).first?[0] else { return nil }
        let trimmed = m.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)]}'"))
        return URL(string: trimmed)
    }
}
