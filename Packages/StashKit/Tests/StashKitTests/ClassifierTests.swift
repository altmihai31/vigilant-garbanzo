import XCTest
@testable import StashKit

final class ClassifierTests: XCTestCase {
    /// Spec: "the sample links in the mockup land in the same collections as shown there".
    func testMockupSamplesLandInTheirCollections() {
        for item in SampleData.items() {
            let got = CollectionClassifier.classify(kind: item.kind, url: item.url, title: item.title, text: item.summary ?? "",
                                                    schemaTypes: [], hasPlace: false)
            XCTAssertEqual(got, item.collection, item.title)
        }
    }

    func testStructuredDataWins() {
        XCTAssertEqual(CollectionClassifier.classify(url: URL(string: "https://blog.example.com/x"), title: "My weekend",
                                                     schemaTypes: ["Recipe"]), .recipes)
        XCTAssertEqual(CollectionClassifier.classify(url: URL(string: "https://example.com/x"), title: "Thing",
                                                     schemaTypes: ["Product"]), .shopping)
        XCTAssertEqual(CollectionClassifier.classify(url: URL(string: "https://example.com/x"), title: "Thing",
                                                     schemaTypes: ["Restaurant"]), .places)
        XCTAssertEqual(CollectionClassifier.classify(url: nil, title: "Anything", hasPlace: true), .places)
    }

    func testShareSheetSamples() {
        XCTAssertEqual(CollectionClassifier.classify(url: SampleData.cacioURL, title: "Cacio e Pepe, the Roman Way"), .recipes)
        XCTAssertEqual(CollectionClassifier.classify(url: SampleData.lisbonURL, title: "Lisbon City Guide: Where to Stay, Eat and Shop"), .places)
        XCTAssertEqual(CollectionClassifier.classify(url: URL(string: "https://www.amazon.com/dp/B0"), title: "Kindle"), .shopping)
        XCTAssertEqual(CollectionClassifier.classify(url: URL(string: "https://www.youtube.com/watch?v=1"), title: "Swift concurrency explained"), .reading)
    }

    func testNotesOnlyGoToShopping() {
        XCTAssertEqual(CollectionClassifier.classify(kind: .note, url: nil, title: "Groceries for Sunday"), .shopping)
        XCTAssertEqual(CollectionClassifier.classify(kind: .note, url: nil, title: "Hike checklist"), .none)
    }

    func testProcessorPipelineWithFallback() async throws {
        let p = LinkProcessor(loader: SampleData.DemoLoader(), summarizer: nil)
        let r = try await p.process(SampleData.lisbonURL)
        XCTAssertEqual(r.title, "Lisbon City Guide: Where to Stay, Eat and Shop")
        XCTAssertEqual(r.collection, .places)
        XCTAssertEqual(r.summarySource, .pageDescription)
        XCTAssertEqual(r.place?.name, "Príncipe Real")
        XCTAssertEqual(r.article?.paragraphs.count, 2)
        XCTAssertEqual(r.imageURL?.absoluteString, "demo://lisbon")
    }

    struct FakeModel: Summarizing {
        func summarize(title: String, text: String) async -> ModelDigest? {
            ModelDigest(summary: "Model summary.", collection: .reading, placeName: "Val di Funes")
        }
    }

    func testProcessorPrefersModelAndUsesItsPlace() async {
        let html = "<head><title>Quiet mornings</title></head><body><p>A long walk under the peaks at sunrise is the best part of any trip there.</p></body>"
        let r = await LinkProcessor(loader: SampleData.DemoLoader(), summarizer: FakeModel())
            .process(html: html, url: URL(string: "https://example.org/a")!)
        XCTAssertEqual(r.summary, "Model summary.")
        XCTAssertEqual(r.summarySource, .onDevice)
        XCTAssertEqual(r.place?.name, "Val di Funes")
        XCTAssertEqual(r.collection, .places)
    }

    func testApplyKeepsManualCollection() async {
        var item = InboxEntry(url: SampleData.cacioURL, title: nil).makeItem()
        item.collection = .shopping
        item.collectionIsManual = true
        let r = await LinkProcessor(loader: SampleData.DemoLoader()).process(html: SampleData.cacioHTML, url: SampleData.cacioURL)
        item.apply(r)
        XCTAssertEqual(item.collection, .shopping)
        XCTAssertEqual(item.title, "Cacio e Pepe, the Roman Way")
        XCTAssertEqual(item.processingState, .done)
        XCTAssertNotNil(item.article)
    }
}
