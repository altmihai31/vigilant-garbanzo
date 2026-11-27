import XCTest
@testable import StashKit

final class StoreAndQueryTests: XCTestCase {
    var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testSaveLoadRoundTrip() throws {
        let store = ItemStore(directory: dir)
        let items = SampleData.items()
        try store.save(items)
        let loaded = ItemStore(directory: dir).load()
        XCTAssertEqual(loaded, items)
    }

    func testLenientDecodingOfOlderFiles() throws {
        let json = #"[{"id":"6F1A4C1E-0000-4000-8000-000000000001","kind":"note","title":"Old","collection":"mystery"}]"#
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.data(using: .utf8)!.write(to: dir.appendingPathComponent("items.json"))
        let items = ItemStore(directory: dir).load()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].collection, StashCollection.none)
        XCTAssertEqual(items[0].checklist, [])
    }

    func testInboxDrainAndMergeDeduplicates() throws {
        let store = ItemStore(directory: dir)
        let url = URL(string: "https://www.example.com/post/")!
        let existing = Item(kind: .link, createdAt: Date(timeIntervalSince1970: 0), title: "Post", url: url)
        let remind = Date(timeIntervalSince1970: 5_000)
        try store.enqueue(InboxEntry(url: URL(string: "https://example.com/post")!, remindAt: remind, createdAt: Date(timeIntervalSince1970: 100)))
        try store.enqueue(InboxEntry(url: URL(string: "https://new.example.com/a")!, title: "New", createdAt: Date(timeIntervalSince1970: 200)))
        let drained = store.drainInbox()
        XCTAssertEqual(drained.count, 2)
        XCTAssertTrue(store.drainInbox().isEmpty, "Drained entries are removed")
        let merged = ItemMerge.merge(drained, into: [existing])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].createdAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(merged[0].remindAt, remind)
        XCTAssertTrue(merged[0].isUnread)
        XCTAssertEqual(merged[1].processingState, .pending)
        XCTAssertEqual(merged[1].title, "New")
    }

    func testFiltersSortAndSearch() {
        let items = SampleData.items()
        XCTAssertEqual(ItemQuery.unreadCount(items), 4)
        XCTAssertEqual(ItemQuery.count(items, filter: .collection(.places)), 4)
        XCTAssertEqual(ItemQuery.count(items, filter: .collection(.recipes)), 1)
        XCTAssertEqual(ItemQuery.count(items, filter: .notes), 3)
        let newest = ItemQuery.apply(items)
        XCTAssertEqual(newest.first?.title, "Top Hotels on the Amalfi Coast")
        XCTAssertEqual(ItemQuery.apply(items, sort: .oldest).first?.title, "The Quiet Trails of the Dolomites")
        // Search reaches the saved article text, the place and checklist items, ignoring accents.
        XCTAssertEqual(ItemQuery.apply(items, search: "omakase").map(\.title), ["Best Sushi Spots in Tokyo for First-Time Visitors"])
        XCTAssertEqual(ItemQuery.apply(items, search: "positano").count, 1)
        XCTAssertEqual(ItemQuery.apply(items, search: "hermes").map(\.title), ["Gift ideas for Mom"])
        XCTAssertEqual(ItemQuery.apply(items, search: "headlamp water").map(\.title), ["Hike checklist"])
        XCTAssertTrue(ItemQuery.apply(items, search: "zzzz").isEmpty)
    }

    func testColumnsStagger() {
        let (l, r) = ItemQuery.columns([1, 2, 3, 4, 5])
        XCTAssertEqual(l, [1, 3, 5])
        XCTAssertEqual(r, [2, 4])
        let (l2, r2) = ItemQuery.columns([1, 2, 3], leadingSlots: 1)
        XCTAssertEqual(l2, [2])
        XCTAssertEqual(r2, [1, 3])
    }

    func testTagsNormalized() {
        XCTAssertEqual(ItemQuery.normalizedTags([" Italy", "#italy", "", "June trip"]), ["Italy", "June trip"])
    }

    func testDeepLinksRoundTrip() {
        let e = InboxEntry(url: URL(string: "https://example.com/a?b=1&c=2")!, title: "A & B", summary: "Sum",
                           collection: .recipes, remindAt: Date(timeIntervalSince1970: 1_800_000_000))
        guard case .save(let parsed)? = StashShared.parse(StashShared.saveURL(for: e), now: e.createdAt) else {
            return XCTFail("save link not parsed")
        }
        XCTAssertEqual(parsed.url, e.url)
        XCTAssertEqual(parsed.title, "A & B")
        XCTAssertEqual(parsed.collection, .recipes)
        XCTAssertEqual(parsed.remindAt, e.remindAt)
        let id = UUID()
        XCTAssertEqual(StashShared.parse(StashShared.itemURL(id)), .item(id))
        XCTAssertNil(StashShared.parse(URL(string: "stash://save?url=javascript:alert(1)")!))
        XCTAssertNil(StashShared.parse(URL(string: "https://example.com")!))
    }

    func testMapsURL() {
        let p = Place(name: "Le Sirenuse", address: "Positano", latitude: 40.6, longitude: 14.4)
        XCTAssertEqual(p.mapsURL.absoluteString, "https://maps.apple.com/?q=Le%20Sirenuse&ll=40.6,14.4")
        XCTAssertEqual(Place(name: "Umi", address: "Aoyama").mapsURL.absoluteString, "https://maps.apple.com/?q=Umi,%20Aoyama")
    }
}
