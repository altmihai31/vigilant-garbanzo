import SwiftUI
import UIKit
import StashKit

/// Link preview shown in the Add sheet before saving.
struct LinkPreview {
    var link: ProcessedLink
    var imageData: Data?
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published var filter: ItemFilter = .all
    @Published var sort: ItemSortOrder = .newest
    @Published var search = ""
    @Published var path: [UUID] = []
    @Published var toastText: String?

    let demo: Bool
    let store: ItemStore
    private let processor: LinkProcessor
    private var processing: Set<UUID> = []
    private var images: [String: UIImage] = [:]
    private var toastTask: Task<Void, Never>?

    init(demo: Bool) {
        self.demo = demo
        if demo {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("StashDemo-\(UUID().uuidString)")
            store = ItemStore(directory: dir)
            processor = LinkProcessor(loader: SampleData.DemoLoader(), summarizer: nil)
            items = SampleData.items()
        } else {
            let dir = StashShared.sharedContainer()
                ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Stash", isDirectory: true)
            store = ItemStore(directory: dir)
            processor = LinkProcessor(loader: URLSessionPageLoader(), summarizer: Summarizers.best())
            items = store.load()
        }
    }

    // MARK: Lifecycle

    /// Runs when the app becomes active: pick up Share Sheet saves, finish pending work, sync reminders and badge.
    func becameActive() {
        let entries = store.drainInbox()
        if !entries.isEmpty {
            items = ItemMerge.merge(entries, into: items)
            persist()
            if !demo, entries.contains(where: { $0.remindAt != nil }) {
                Task { await ReminderScheduler.requestAuthorization() }
            }
        }
        processPending()
        if !demo {
            ReminderScheduler.resync(items)
            ReminderScheduler.setBadge(unreadCount)
        }
    }

    func handle(url: URL) {
        switch StashShared.parse(url) {
        case .save(let entry)?:
            items = ItemMerge.merge([entry], into: items)
            persist()
            reminderChanged(entry.id)
            processPending()
            path = []
            filter = .all
            showToast("Saved to Stash")
        case .item(let id)?:
            open(id)
        case nil:
            break
        }
    }

    func open(_ id: UUID) {
        guard items.contains(where: { $0.id == id }) else { return }
        path = [id]
    }

    // MARK: Queries

    var visibleItems: [Item] { ItemQuery.apply(items, filter: filter, sort: sort, search: search) }
    var unreadCount: Int { ItemQuery.unreadCount(items) }
    func count(_ f: ItemFilter) -> Int { ItemQuery.count(items, filter: f) }
    func item(_ id: UUID) -> Item? { items.first { $0.id == id } }

    func image(for item: Item) -> UIImage? {
        if let art = item.demoArt { return DemoArt.image(named: art) }
        guard let name = item.imageFileName else { return nil }
        if let cached = images[name] { return cached }
        guard let img = UIImage(contentsOfFile: store.imageURL(named: name).path) else { return nil }
        images[name] = img
        return img
    }

    // MARK: Changes

    func update(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        persist()
    }

    func markRead(_ id: UUID, toast: Bool = true) {
        guard item(id)?.isUnread == true else { return }
        update(id) { $0.markRead() }
        reminderChanged(id)
        if toast { showToast("Marked as read") }
    }

    func markUnread(_ id: UUID) {
        update(id) { $0.isUnread = true }
        reminderChanged(id)
    }

    /// Picking the selected preset again clears the reminder.
    func toggleReminder(_ id: UUID, preset: ReminderPreset) {
        guard let current = item(id) else { return }
        let date = preset.date()
        if ReminderPreset.matching(current.remindAt) == preset {
            update(id) { $0.remindAt = nil }
        } else {
            update(id) {
                $0.remindAt = date
                $0.isUnread = true
            }
            showToast("Reminder set: " + DateText.reminder(date))
            if !demo { Task { await ReminderScheduler.requestAuthorization() } }
        }
        reminderChanged(id)
    }

    private func reminderChanged(_ id: UUID) {
        guard !demo else { return }
        if let it = item(id) { ReminderScheduler.schedule(it) } else { ReminderScheduler.cancel(id) }
        ReminderScheduler.setBadge(unreadCount)
    }

    func setCollection(_ id: UUID, _ c: StashCollection) {
        update(id) {
            $0.collection = c
            $0.collectionIsManual = true
        }
        showToast(c == .none ? "Removed from collections" : "Moved to \(c.name)")
    }

    func addTag(_ id: UUID, _ tag: String) {
        update(id) { $0.tags = ItemQuery.normalizedTags($0.tags + [tag]) }
    }

    func removeTag(_ id: UUID, _ tag: String) {
        update(id) { $0.tags.removeAll { $0 == tag } }
    }

    func toggleChecklist(_ id: UUID, _ entry: UUID) {
        update(id) { item in
            if let i = item.checklist.firstIndex(where: { $0.id == entry }) { item.checklist[i].done.toggle() }
        }
    }

    func delete(_ id: UUID) {
        let img = item(id)?.imageFileName
        items.removeAll { $0.id == id }
        store.deleteImage(named: img)
        persist()
        if !demo {
            ReminderScheduler.cancel(id)
            ReminderScheduler.setBadge(unreadCount)
        }
        path.removeAll { $0 == id }
        showToast("Deleted")
    }

    // MARK: Adding

    func normalizedURL(_ text: String) -> URL? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let found = StashShared.firstURL(in: t) { return found }
        if !t.contains("://") { t = "https://" + t }
        guard let u = URL(string: t), let host = u.host, host.contains(".") else { return nil }
        return u
    }

    /// Fetches the page for the Add sheet preview.
    func preview(_ url: URL) async -> LinkPreview? {
        guard let link = try? await processor.process(url) else { return nil }
        var data: Data?
        if let img = link.imageURL { data = await ImageFetcher.jpeg(from: img) }
        return LinkPreview(link: link, imageData: data)
    }

    func addLink(url: URL, note: String, preview: LinkPreview?) {
        var item = Item(kind: .link, title: url.host ?? url.absoluteString, url: url, note: note.isEmpty ? nil : note,
                        processingState: .pending)
        if let p = preview {
            item.apply(p.link)
            if let data = p.imageData { item.imageFileName = try? store.writeImage(data, for: item.id) }
            if let place = item.place, !place.hasCoordinate { item.processingState = .pending }
        }
        insert(item)
        showToast("Link saved")
        processPending()
    }

    func saveNote(id: UUID?, title: String, body: String, checklist: [ChecklistItem]) {
        let cleanList = checklist.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = t.isEmpty ? String(b.split(separator: "\n").first?.prefix(40) ?? "Note") : t
        if let id, item(id) != nil {
            update(id) {
                $0.title = finalTitle
                $0.body = b.isEmpty ? nil : b
                $0.checklist = cleanList
                if !$0.collectionIsManual {
                    $0.collection = CollectionClassifier.classify(kind: .note, url: nil, title: finalTitle,
                                                                  text: b + " " + cleanList.map(\.text).joined(separator: " "))
                }
            }
            showToast("Note saved")
        } else {
            let c = CollectionClassifier.classify(kind: .note, url: nil, title: finalTitle,
                                                  text: b + " " + cleanList.map(\.text).joined(separator: " "))
            insert(Item(kind: .note, title: finalTitle, body: b.isEmpty ? nil : b, checklist: cleanList, collection: c))
            showToast("Note saved")
        }
    }

    private func insert(_ item: Item) {
        items.append(item)
        filter = .all
        sort = .newest
        search = ""
        persist()
    }

    // MARK: Processing

    /// Fetch page, summary, collection, image, offline copy and map location for links that still need them.
    func processPending() {
        for item in items where item.kind == .link && item.processingState == .pending && !processing.contains(item.id) {
            processing.insert(item.id)
            Task { await process(item.id) }
        }
    }

    private func process(_ id: UUID) async {
        defer { processing.remove(id) }
        guard var item = item(id), let url = item.url else { return }
        if item.article == nil {
            if let result = try? await processor.process(url) {
                let imageURL = result.imageURL
                item.apply(result)
                if item.imageFileName == nil, let imageURL, let data = await ImageFetcher.jpeg(from: imageURL) {
                    item.imageFileName = try? store.writeImage(data, for: id)
                }
            } else if item.article == nil {
                item.processingState = .failed
            }
        }
        if let place = item.place, !place.hasCoordinate, !demo {
            item.place = await PlaceLocator.locate(place)
        }
        if item.processingState == .pending { item.processingState = .done }
        // The item may have changed while we were fetching; keep those edits.
        update(id) { current in
            let keep = current
            current = item
            current.isUnread = keep.isUnread
            current.remindAt = keep.remindAt
            current.tags = keep.tags
            current.note = keep.note
            if keep.collectionIsManual {
                current.collection = keep.collection
                current.collectionIsManual = true
            }
        }
    }

    // MARK: Misc

    private func persist() {
        try? store.save(items)
        if !demo { ReminderScheduler.setBadge(unreadCount) }
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { toastText = text }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { toastText = nil }
        }
    }
}
