import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches a page's HTML.
public protocol PageLoading: Sendable {
    func load(_ url: URL) async throws -> (html: String, finalURL: URL)
}

/// The on-device model in the app; absent (nil result) on phones without Apple Intelligence.
public protocol Summarizing: Sendable {
    func summarize(title: String, text: String) async -> ModelDigest?
}

/// What the on-device model returns for a page.
public struct ModelDigest: Equatable, Sendable {
    public var summary: String
    public var collection: StashCollection?
    public var placeName: String?

    public init(summary: String, collection: StashCollection? = nil, placeName: String? = nil) {
        self.summary = summary
        self.collection = collection
        self.placeName = placeName
    }
}

/// Everything Stash learns about a link.
public struct ProcessedLink: Equatable, Sendable {
    public var url: URL
    public var title: String
    public var summary: String?
    public var summarySource: SummarySource
    public var siteName: String?
    public var imageURL: URL?
    public var collection: StashCollection
    public var place: Place?
    public var article: Article?
}

/// Default loader: URLSession with a phone user agent and a size cap.
public struct URLSessionPageLoader: PageLoading {
    public var timeout: TimeInterval
    public var maxBytes: Int

    public init(timeout: TimeInterval = 15, maxBytes: Int = 4_000_000) {
        self.timeout = timeout
        self.maxBytes = maxBytes
    }

    public func load(_ url: URL) async throws -> (html: String, finalURL: URL) {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let slice = data.count > maxBytes ? data.prefix(maxBytes) : data
        let html = String(data: slice, encoding: .utf8) ?? String(decoding: slice, as: UTF8.self)
        return (html, response.url ?? url)
    }
}

public struct LinkProcessor: Sendable {
    public var loader: PageLoading
    public var summarizer: Summarizing?
    public var now: @Sendable () -> Date

    public init(loader: PageLoading, summarizer: Summarizing? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.loader = loader
        self.summarizer = summarizer
        self.now = now
    }

    /// Fetch, extract the article, summarise (model first, page description as fallback) and pick a collection.
    public func process(_ url: URL) async throws -> ProcessedLink {
        let (html, finalURL) = try await loader.load(url)
        return await process(html: html, url: finalURL)
    }

    public func process(html: String, url: URL) async -> ProcessedLink {
        let md = PageMetadataParser.parse(html: html, baseURL: url)
        let paragraphs = ArticleExtractor.extract(html: html)
        let title = md.title?.isEmpty == false ? md.title! : (url.host ?? url.absoluteString)
        let text = paragraphs.joined(separator: "\n")

        var summary: String?
        var source = SummarySource.none
        var digest: ModelDigest?
        if let summarizer, !(text.isEmpty && (md.description ?? "").isEmpty) {
            digest = await summarizer.summarize(title: title, text: text.isEmpty ? (md.description ?? "") : text)
            if let d = digest, !d.summary.isEmpty {
                summary = d.summary
                source = .onDevice
            }
        }
        if summary == nil, let fb = FallbackSummarizer.summary(description: md.description, paragraphs: paragraphs) {
            summary = fb
            source = .pageDescription
        }

        var place = md.place
        if place == nil, let name = digest?.placeName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            place = Place(name: name)
        }
        var collection = CollectionClassifier.classify(url: url, title: title, text: (md.description ?? "") + "\n" + text,
                                                       schemaTypes: md.schemaTypes, hasPlace: md.place != nil)
        // Structured data and known sites win; otherwise trust the model's pick when it made one.
        if collection == .reading, let c = digest?.collection, c != .none { collection = c }
        // A place found in the article puts a general link into Places.
        if place != nil, collection == .reading { collection = .places }
        if collection == .recipes || collection == .shopping, md.place == nil { place = nil }

        let article = paragraphs.isEmpty ? nil : Article(paragraphs: paragraphs, savedAt: now())
        return ProcessedLink(url: url, title: title, summary: summary, summarySource: source, siteName: md.siteName,
                             imageURL: md.imageURL, collection: collection, place: place, article: article)
    }
}

extension Item {
    /// Applies processing results, keeping anything the person chose by hand.
    public mutating func apply(_ p: ProcessedLink) {
        if title.isEmpty || title == url?.host || title == url?.absoluteString || processingState == .pending {
            title = p.title
        }
        if p.summary != nil || summary == nil {
            summary = p.summary ?? summary
            summarySource = p.summary != nil ? p.summarySource : summarySource
        }
        siteName = p.siteName ?? siteName
        if !collectionIsManual { collection = p.collection }
        if place == nil { place = p.place }
        if let a = p.article { article = a }
        processingState = .done
    }
}
