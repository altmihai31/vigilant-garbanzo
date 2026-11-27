import XCTest
@testable import StashKit

final class ParsingTests: XCTestCase {
    func testOpenGraphAndEntities() {
        let html = """
        <html><head><title>Fallback &amp; title</title>
        <meta property="og:title" content="Caf&eacute; guide &#8211; Lisbon">
        <meta content='Short &quot;quoted&quot; description of the page.' name='description'>
        <meta property="og:image" content="/img/hero.jpg">
        <meta property="og:site_name" content="Monocle"></head><body></body></html>
        """
        let md = PageMetadataParser.parse(html: html, baseURL: URL(string: "https://monocle.com/travel/x"))
        XCTAssertEqual(md.title, "Café guide \u{2013} Lisbon")
        XCTAssertEqual(md.description, "Short \"quoted\" description of the page.")
        XCTAssertEqual(md.imageURL?.absoluteString, "https://monocle.com/img/hero.jpg")
        XCTAssertEqual(md.siteName, "Monocle")
    }

    func testTitleTagFallbackAndProtocolRelativeImage() {
        let html = "<head><title>\n  Plain   title </title><meta name=\"twitter:image\" content=\"//cdn.x.com/a.png\"></head>"
        let md = PageMetadataParser.parse(html: html, baseURL: nil)
        XCTAssertEqual(md.title, "Plain title")
        XCTAssertEqual(md.imageURL?.absoluteString, "https://cdn.x.com/a.png")
    }

    func testJSONLDRecipeAndPlace() {
        let md = PageMetadataParser.parse(html: SampleData.cacioHTML, baseURL: SampleData.cacioURL)
        XCTAssertTrue(md.schemaTypes.contains("Recipe"))
        let lisbon = PageMetadataParser.parse(html: SampleData.lisbonHTML, baseURL: SampleData.lisbonURL)
        XCTAssertEqual(lisbon.place?.name, "Príncipe Real")
        XCTAssertEqual(lisbon.place?.city, "Lisbon, Portugal")
        XCTAssertEqual(lisbon.place?.latitude ?? 0, 38.7167, accuracy: 0.001)
    }

    func testJSONLDGraphHotelWithStringGeo() {
        let html = """
        <head><script type="application/ld+json">{"@graph":[{"@type":"WebPage"},{"@type":["Hotel","LocalBusiness"],"name":"Le Sirenuse",
        "address":{"streetAddress":"Via Cristoforo Colombo 30","addressLocality":"Positano","addressCountry":{"@type":"Country","name":"Italy"}},
        "geo":{"latitude":"40.6281","longitude":"14.485"}}]}</script></head>
        """
        let md = PageMetadataParser.parse(html: html, baseURL: nil)
        XCTAssertEqual(md.place?.name, "Le Sirenuse")
        XCTAssertEqual(md.place?.address, "Via Cristoforo Colombo 30, Positano")
        XCTAssertEqual(md.place?.city, "Positano, Italy")
        XCTAssertEqual(md.place?.longitude ?? 0, 14.485, accuracy: 0.0001)
        XCTAssertTrue(md.schemaTypes.contains("Hotel"))
    }

    func testBrokenJSONLDIsIgnored() {
        let html = "<head><script type=\"application/ld+json\">{not json</script><meta property=\"og:title\" content=\"Ok\"></head>"
        XCTAssertEqual(PageMetadataParser.parse(html: html, baseURL: nil).title, "Ok")
    }

    func testArticleExtractionSkipsChrome() {
        let ps = ArticleExtractor.extract(html: SampleData.lisbonHTML)
        XCTAssertEqual(ps.count, 2)
        XCTAssertTrue(ps[0].hasPrefix("Lisbon rewards slow weekends."))
        XCTAssertTrue(ps[0].contains("city\u{2019}s best bookshop"))
        XCTAssertFalse(ps.joined().contains("newsletter"))
        XCTAssertFalse(ps.joined().contains("All rights reserved"))
    }

    func testArticleExtractionWithoutArticleTag() {
        let html = "<body><script>var x = '<p>not this paragraph, it is code inside a script tag</p>';</script><div><p>Short.</p><p>This paragraph is long enough to be kept as part of the readable article text.</p></div></body>"
        XCTAssertEqual(ArticleExtractor.extract(html: html), ["This paragraph is long enough to be kept as part of the readable article text."])
    }

    func testReadingMinutes() {
        let words = Array(repeating: "word", count: 660).joined(separator: " ")
        XCTAssertEqual(ArticleExtractor.readingMinutes(for: [words]), 3)
        XCTAssertEqual(ArticleExtractor.readingMinutes(for: []), 1)
    }

    func testFallbackSummary() {
        XCTAssertEqual(FallbackSummarizer.summary(description: "A description that is long enough to use.", paragraphs: []),
                       "A description that is long enough to use.")
        let s = FallbackSummarizer.summary(description: "Too short", paragraphs: ["First sentence is here. Second one follows! Third is dropped."])
        XCTAssertEqual(s, "First sentence is here. Second one follows!")
        let long = String(repeating: "abcd ", count: 100)
        XCTAssertLessThanOrEqual(FallbackSummarizer.summary(description: long, paragraphs: [])!.count, 241)
        XCTAssertNil(FallbackSummarizer.summary(description: nil, paragraphs: []))
    }

    func testFirstURLInSharedText() {
        XCTAssertEqual(StashShared.firstURL(in: "Watch this https://youtu.be/abc123?t=4.")?.absoluteString, "https://youtu.be/abc123?t=4")
        XCTAssertNil(StashShared.firstURL(in: "no link here"))
    }

    func testEntityEdgeCases() {
        XCTAssertEqual(HTMLText.decodeEntities("a &unknown; b &#x41; &#66; &"), "a &unknown; b A B &")
        XCTAssertEqual(HTMLText.plainText("<b>Bold</b><br/>next&nbsp;line"), "Bold next line")
    }
}
