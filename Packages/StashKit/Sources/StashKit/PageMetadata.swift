import Foundation

/// What Stash reads from a page's head: Open Graph and meta tags, plus JSON-LD structured data.
public struct PageMetadata: Equatable, Sendable {
    public var title: String?
    public var description: String?
    public var imageURL: URL?
    public var siteName: String?
    /// Schema.org types from JSON-LD (`Recipe`, `Restaurant`...) plus the `og:type`.
    public var schemaTypes: [String]
    /// A place described by the page's structured data.
    public var place: Place?

    public init(title: String? = nil, description: String? = nil, imageURL: URL? = nil, siteName: String? = nil,
                schemaTypes: [String] = [], place: Place? = nil) {
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.siteName = siteName
        self.schemaTypes = schemaTypes
        self.place = place
    }
}

public enum PageMetadataParser {
    /// Schema.org types that describe somewhere you can go.
    public static let placeTypes: Set<String> = [
        "place", "localbusiness", "restaurant", "foodestablishment", "cafeorcoffeeshop", "barorpub", "bakery",
        "hotel", "lodgingbusiness", "resort", "bedandbreakfast", "hostel", "motel", "vacationrental",
        "touristattraction", "touristdestination", "landmarksorhistoricalbuildings", "museum", "park", "beach",
        "campground", "city", "civicstructure"
    ]

    public static func parse(html: String, baseURL: URL?) -> PageMetadata {
        // Only the head matters for meta tags; fall back to the whole page if there is no </head>.
        let headEnd = html.range(of: "</head", options: .caseInsensitive)?.lowerBound ?? html.endIndex
        let head = String(html[..<headEnd])

        var meta: [String: String] = [:]
        for m in HTMLText.matches("<meta\\b[^>]*>", in: head) {
            guard let tag = m[0] else { continue }
            let attrs = HTMLText.attributes(ofTag: tag)
            guard let key = (attrs["property"] ?? attrs["name"] ?? attrs["itemprop"])?.lowercased(),
                  let content = attrs["content"] else { continue }
            let value = HTMLText.collapseWhitespace(content)
            if !value.isEmpty, meta[key] == nil { meta[key] = value }
        }

        var md = PageMetadata()
        let titleTag = HTMLText.matches("<title[^>]*>(.*?)</title>", in: head, options: [.caseInsensitive, .dotMatchesLineSeparators])
            .first?[1].map { HTMLText.plainText($0) }
        md.title = meta["og:title"] ?? meta["twitter:title"] ?? titleTag.flatMap { $0.isEmpty ? nil : $0 }
        md.description = meta["og:description"] ?? meta["twitter:description"] ?? meta["description"]
        md.siteName = meta["og:site_name"] ?? meta["application-name"]
        if let img = meta["og:image:secure_url"] ?? meta["og:image"] ?? meta["og:image:url"] ?? meta["twitter:image"] ?? meta["twitter:image:src"] {
            md.imageURL = resolve(img, against: baseURL)
        }

        var types: [String] = []
        if let og = meta["og:type"] { types.append(og) }
        var place: Place?
        for m in HTMLText.matches("<script[^>]*application/ld\\+json[^>]*>(.*?)</script>", in: html,
                                  options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            guard let raw = m[1]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { continue }
            walk(json) { node in
                let nodeTypes = typeNames(node["@type"])
                types.append(contentsOf: nodeTypes)
                if place == nil, nodeTypes.contains(where: { placeTypes.contains($0.lowercased()) }) {
                    place = makePlace(node)
                }
                if md.imageURL == nil, nodeTypes.contains(where: { ["recipe", "article", "newsarticle", "product"].contains($0.lowercased()) }),
                   let img = imageString(node["image"]) {
                    md.imageURL = resolve(img, against: baseURL)
                }
            }
        }
        var seen = Set<String>()
        md.schemaTypes = types.filter { seen.insert($0.lowercased()).inserted }
        md.place = place
        if md.title != nil { md.title = HTMLText.decodeEntities(md.title!) }
        return md
    }

    static func resolve(_ s: String, against base: URL?) -> URL? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("//") { return URL(string: "https:" + t) }
        if let u = URL(string: t), u.scheme != nil { return u }
        if let base { return URL(string: t, relativeTo: base)?.absoluteURL }
        return nil
    }

    private static func walk(_ json: Any, _ visit: ([String: Any]) -> Void) {
        if let arr = json as? [Any] {
            arr.forEach { walk($0, visit) }
        } else if let dict = json as? [String: Any] {
            visit(dict)
            if let graph = dict["@graph"] { walk(graph, visit) }
            for key in ["mainEntity", "itemReviewed", "about", "location", "containedInPlace"] {
                if let child = dict[key] { walk(child, visit) }
            }
            if let list = dict["itemListElement"] as? [Any] {
                for el in list {
                    if let d = el as? [String: Any], let inner = d["item"] { walk(inner, visit) } else { walk(el, visit) }
                }
            }
        }
    }

    private static func typeNames(_ v: Any?) -> [String] {
        if let s = v as? String { return [s] }
        if let a = v as? [Any] { return a.compactMap { $0 as? String } }
        return []
    }

    private static func imageString(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let a = v as? [Any], let first = a.first { return imageString(first) }
        if let d = v as? [String: Any] { return d["url"] as? String }
        return nil
    }

    private static func string(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let d = v as? [String: Any] { return d["name"] as? String }
        if let a = v as? [Any], let first = a.first { return string(first) }
        return nil
    }

    private static func double(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    private static func makePlace(_ node: [String: Any]) -> Place? {
        guard let rawName = node["name"] as? String else { return nil }
        let name = HTMLText.plainText(rawName)
        guard !name.isEmpty else { return nil }
        var address: String?
        var city: String?
        if let a = node["address"] as? String {
            address = HTMLText.collapseWhitespace(a)
        } else if let a = (node["address"] as? [String: Any]) ?? ((node["address"] as? [Any])?.first as? [String: Any]) {
            let street = a["streetAddress"] as? String
            let locality = a["addressLocality"] as? String
            let region = a["addressRegion"] as? String
            let country = string(a["addressCountry"])
            city = [locality, country ?? region].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            if city?.isEmpty == true { city = nil }
            let parts = [street, locality, region].compactMap { $0 }.filter { !$0.isEmpty }
            address = parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
        var lat: Double?
        var lon: Double?
        if let geo = node["geo"] as? [String: Any] {
            lat = double(geo["latitude"])
            lon = double(geo["longitude"])
        }
        return Place(name: name, address: address.map(HTMLText.decodeEntities), city: city.map(HTMLText.decodeEntities),
                     latitude: lat, longitude: lon)
    }
}
