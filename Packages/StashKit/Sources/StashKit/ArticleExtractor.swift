import Foundation

/// Pulls the readable paragraphs out of a page, for the offline copy, the summary and search.
public enum ArticleExtractor {
    static let noise = ["script", "style", "noscript", "svg", "nav", "header", "footer", "aside", "form", "button",
                        "figcaption", "iframe", "template", "select"]

    static let boilerplate = ["cookie", "subscribe to", "newsletter", "all rights reserved", "sign up for",
                              "privacy policy", "terms of use", "advertisement", "javascript", "log in to",
                              "affiliate commission", "share this"]

    public static func extract(html: String) -> [String] {
        let cleaned = HTMLText.removingElements(noise, from: html)
        let region = mainRegion(of: cleaned)
        var paragraphs: [String] = []
        for m in HTMLText.matches("<(p|li|blockquote|h2|h3)\\b[^>]*>(.*?)</\\1\\s*>", in: region,
                                  options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            guard let tag = m[1]?.lowercased(), let inner = m[2] else { continue }
            let text = HTMLText.plainText(inner)
            let words = text.split(separator: " ").count
            if tag == "p" || tag == "blockquote" {
                guard text.count >= 40 || words >= 8 else { continue }
            } else if tag == "li" {
                // Ingredient and step lists matter for recipes; short menu links do not.
                guard words >= 3, text.count >= 12 else { continue }
            } else {
                continue // headings help find the region but are not kept as paragraphs
            }
            let lower = text.lowercased()
            if boilerplate.contains(where: { lower.contains($0) }) && words < 40 { continue }
            if paragraphs.last != text { paragraphs.append(text) }
        }
        return paragraphs
    }

    /// The `<article>` (or `<main>`) with the most paragraph text, else the body.
    static func mainRegion(of html: String) -> String {
        for tag in ["article", "main"] {
            let candidates = HTMLText.matches("<\(tag)\\b[^>]*>(.*?)</\(tag)\\s*>", in: html,
                                              options: [.caseInsensitive, .dotMatchesLineSeparators]).compactMap { $0[1] }
            if let best = candidates.max(by: { paragraphWeight($0) < paragraphWeight($1) }), paragraphWeight(best) > 200 {
                return best
            }
        }
        if let body = HTMLText.matches("<body\\b[^>]*>(.*)</body", in: html, options: [.caseInsensitive, .dotMatchesLineSeparators]).first?[1] {
            return body
        }
        return html
    }

    private static func paragraphWeight(_ html: String) -> Int {
        HTMLText.matches("<p\\b[^>]*>(.*?)</p", in: html, options: [.caseInsensitive, .dotMatchesLineSeparators])
            .reduce(0) { $0 + ($1[1]?.count ?? 0) }
    }

    /// About 220 words a minute, at least one minute.
    public static func readingMinutes(for paragraphs: [String]) -> Int {
        let words = paragraphs.reduce(0) { $0 + $1.split(separator: " ").count }
        return max(1, Int((Double(words) / 220).rounded()))
    }
}

/// The summary used when the on-device model is not available.
public enum FallbackSummarizer {
    /// The page description if it is long enough, else the first two sentences of the article.
    public static func summary(description: String?, paragraphs: [String], maxLength: Int = 240) -> String? {
        if let d = description.map(HTMLText.collapseWhitespace), d.count >= 30 {
            return clip(d, to: maxLength)
        }
        guard let first = paragraphs.first(where: { $0.count >= 40 }) else {
            return description.flatMap { $0.isEmpty ? nil : $0 }
        }
        let two = HTMLText.sentences(first).prefix(2).joined(separator: " ")
        return clip(two, to: maxLength)
    }

    static func clip(_ s: String, to n: Int) -> String {
        guard s.count > n else { return s }
        let cut = s.prefix(n)
        if let space = cut.lastIndex(of: " ") { return String(cut[..<space]) + "\u{2026}" }
        return String(cut) + "\u{2026}"
    }
}
