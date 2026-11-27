import UIKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import StashKit

/// Share Extension: shows the Save to Stash card, writes an inbox entry to the shared container and closes.
/// The main app fetches the summary, collection and offline copy the next time it is active.
final class ShareViewController: UIViewController {
    private let state = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let root = ShareRoot(state: state,
                             onCancel: { [weak self] in self?.cancel() },
                             onSave: { [weak self] in self?.save() })
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        Task { await loadSharedItem() }
    }

    // MARK: Reading what was shared

    private func loadSharedItem() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var url: URL?
        var text: String?
        for item in items {
            if text == nil, let t = item.attributedContentText?.string, !t.isEmpty { text = t }
            for provider in item.attachments ?? [] {
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let u = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL, u.scheme?.hasPrefix("http") == true {
                    url = u
                }
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let t = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) as? String {
                    url = StashShared.firstURL(in: t)
                    if text == nil { text = t }
                }
            }
        }
        if url == nil, let text { url = StashShared.firstURL(in: text) }
        guard let url else {
            await MainActor.run {
                state.title = "Nothing to save"
                state.host = "Share a web page or a link"
                state.loading = false
                state.failed = true
            }
            return
        }
        let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        await MainActor.run {
            state.url = url
            state.host = host
            state.title = host
            state.collection = CollectionClassifier.classify(url: url, title: "")
        }

        // A quick look at the page head for the title, image and description. The app does the full work later.
        let loader = URLSessionPageLoader(timeout: 6, maxBytes: 600_000)
        if let page = try? await loader.load(url) {
            let final = page.finalURL
            let md = PageMetadataParser.parse(html: page.html, baseURL: final)
            var image: UIImage?
            var imageData: Data?
            if let imgURL = md.imageURL, imgURL.scheme?.hasPrefix("http") == true,
               let fetched = try? await URLSession.shared.data(from: imgURL), let img = UIImage(data: fetched.0) {
                image = Self.thumbnail(img)
                imageData = image?.jpegData(compressionQuality: 0.8)
            }
            let title = md.title ?? host
            let summary = md.description.flatMap { FallbackSummarizer.summary(description: $0, paragraphs: []) }
            let collection = CollectionClassifier.classify(url: final, title: title, text: md.description ?? "",
                                                           schemaTypes: md.schemaTypes, hasPlace: md.place != nil)
            await MainActor.run {
                state.title = title
                state.summary = summary
                state.siteName = md.siteName
                state.image = image
                state.imageData = imageData
                state.collection = collection
                state.loading = false
            }
        } else {
            await MainActor.run { state.loading = false }
        }
    }

    private static func thumbnail(_ img: UIImage) -> UIImage {
        let maxW: CGFloat = 900
        guard img.size.width > maxW else { return img }
        let size = CGSize(width: maxW, height: (img.size.height * maxW / img.size.width).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }

    // MARK: Saving

    private func save() {
        guard let url = state.url else { return cancel() }
        let remindAt = state.reminder?.date()
        var entry = InboxEntry(url: url, title: state.title == state.host ? nil : state.title, summary: state.summary,
                               siteName: state.siteName, collection: state.collection, remindAt: remindAt)
        if let dir = StashShared.sharedContainer() {
            let store = ItemStore(directory: dir)
            if let data = state.imageData { entry.imageFileName = try? store.writeImage(data, for: entry.id) }
            do {
                try store.enqueue(entry)
                if remindAt != nil { scheduleReminder(entry) }
                withAnimation(.easeOut(duration: 0.25)) { state.saved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
                return
            } catch {
                // fall through to handing the save to the app
            }
        }
        // No shared container (the App Group did not survive signing): hand the save to the app by URL.
        withAnimation(.easeOut(duration: 0.25)) { state.saved = true }
        let link = StashShared.saveURL(for: entry)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            _ = self.openHostApp(link)
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func scheduleReminder(_ entry: InboxEntry) {
        guard let date = entry.remindAt else { return }
        let content = UNMutableNotificationContent()
        content.title = "Read later"
        content.body = entry.title ?? entry.url.host ?? "Saved link"
        content.sound = .default
        content.userInfo = ["itemID": entry.id.uuidString]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "stash-remind-" + entry.id.uuidString, content: content,
                                                                     trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }

    /// Extensions cannot call UIApplication.open directly; walk the responder chain to the application.
    private func openHostApp(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let r = responder {
            if r is UIApplication, r.responds(to: selector), let imp = r.method(for: selector) {
                typealias OpenFn = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
                let fn = unsafeBitCast(imp, to: OpenFn.self)
                fn(r, selector, url as NSURL, NSDictionary(), nil)
                return true
            }
            responder = r.next
        }
        return false
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "Stash", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cancelled"]))
    }
}

@MainActor
final class ShareState: ObservableObject {
    @Published var url: URL?
    @Published var title = "Loading\u{2026}"
    @Published var host = ""
    @Published var siteName: String?
    @Published var summary: String?
    @Published var image: UIImage?
    @Published var imageData: Data?
    @Published var collection: StashCollection?
    @Published var reminder: ReminderPreset? = .tonight
    @Published var loading = true
    @Published var saved = false
    @Published var failed = false
}

struct ShareRoot: View {
    @ObservedObject var state: ShareState
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: onCancel)
            ShareCardView(title: state.title, host: state.host, image: state.image, summary: state.summary,
                          loading: state.loading, collection: state.collection, reminder: $state.reminder,
                          saved: state.saved, onCancel: onCancel, onSave: onSave)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
        }
        .preferredColorScheme(.dark)
    }
}
