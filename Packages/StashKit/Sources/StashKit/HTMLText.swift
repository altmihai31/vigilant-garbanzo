import Foundation

/// Small, dependency-free helpers for pulling text out of HTML.
public enum HTMLText {
    /// All matches of `pattern` in `text`, as arrays of capture groups (index 0 is the whole match).
    static func matches(_ pattern: String, in text: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> [[String?]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
        }
    }

    static func replacing(_ pattern: String, in text: String, with template: String,
                          options: NSRegularExpression.Options = [.caseInsensitive]) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        return re.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: template)
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "rsquo": "\u{2019}", "lsquo": "\u{2018}", "rdquo": "\u{201D}", "ldquo": "\u{201C}",
        "mdash": "\u{2014}", "ndash": "\u{2013}", "hellip": "\u{2026}", "middot": "\u{00B7}", "bull": "\u{2022}",
        "copy": "\u{00A9}", "reg": "\u{00AE}", "trade": "\u{2122}", "deg": "\u{00B0}", "euro": "\u{20AC}", "pound": "\u{00A3}",
        "eacute": "\u{00E9}", "egrave": "\u{00E8}", "aacute": "\u{00E1}", "agrave": "\u{00E0}", "iacute": "\u{00ED}",
        "oacute": "\u{00F3}", "uacute": "\u{00FA}", "ntilde": "\u{00F1}", "ccedil": "\u{00E7}", "uuml": "\u{00FC}",
        "ouml": "\u{00F6}", "auml": "\u{00E4}", "szlig": "\u{00DF}", "times": "\u{00D7}", "frac12": "\u{00BD}",
        "laquo": "\u{00AB}", "raquo": "\u{00BB}", "shy": ""
    ]

    /// Decodes named and numeric character references.
    public static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        out.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            let ch = s[i]
            if ch == "&", let semi = s[i...].prefix(12).firstIndex(of: ";") {
                let entity = String(s[s.index(after: i)..<semi])
                var replacement: String?
                if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                    if let v = UInt32(entity.dropFirst(2), radix: 16), let u = Unicode.Scalar(v) { replacement = String(Character(u)) }
                } else if entity.hasPrefix("#") {
                    if let v = UInt32(entity.dropFirst()), let u = Unicode.Scalar(v) { replacement = String(Character(u)) }
                } else {
                    replacement = named[entity] ?? named[entity.lowercased()]
                }
                if let r = replacement {
                    out += r
                    i = s.index(after: semi)
                    continue
                }
            }
            out.append(ch)
            i = s.index(after: i)
        }
        return out
    }

    /// Removes tags, decodes entities and collapses whitespace.
    public static func plainText(_ html: String) -> String {
        var s = replacing("<br\\s*/?>", in: html, with: " ")
        s = replacing("<[^>]+>", in: s, with: "")
        s = decodeEntities(s)
        return collapseWhitespace(s)
    }

    public static func collapseWhitespace(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Drops whole elements (with their content), such as scripts and navigation.
    static func removingElements(_ names: [String], from html: String) -> String {
        var s = html
        for n in names {
            s = replacing("<\(n)\\b[^>]*>.*?</\(n)\\s*>", in: s, with: " ", options: [.caseInsensitive, .dotMatchesLineSeparators])
        }
        s = replacing("<!--.*?-->", in: s, with: " ", options: [.dotMatchesLineSeparators])
        return s
    }

    /// Attributes of a single start tag such as `<meta property="og:title" content="x">`.
    static func attributes(ofTag tag: String) -> [String: String] {
        var out: [String: String] = [:]
        for m in matches("([a-zA-Z_:][-a-zA-Z0-9_:.]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))", in: tag) {
            guard let key = m[1]?.lowercased() else { continue }
            let value = m[2] ?? m[3] ?? m[4] ?? ""
            if out[key] == nil { out[key] = decodeEntities(value) }
        }
        return out
    }

    /// Splits text into sentences (simple punctuation rule).
    public static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, c) in chars.enumerated() {
            current.append(c)
            if ".!?".contains(c) {
                let next = i + 1 < chars.count ? chars[i + 1] : " "
                if next == " " || next == "\n" {
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { result.append(trimmed) }
                    current = ""
                }
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { result.append(rest) }
        return result
    }
}
