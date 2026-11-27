import Foundation
import UIKit
import MapKit
import UserNotifications
import StashKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - On-device summaries

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct PageDigest {
    @Guide(description: "A one or two sentence summary of the page, at most 200 characters, in the page's language. Plain text, no quotes.")
    var summary: String
    @Guide(description: "The best collection for the page. Exactly one of: places, recipes, reading, shopping. Use places for hotels, restaurants, destinations and travel; recipes for cooking; shopping for products, reviews of things to buy and gifts; reading for everything else.")
    var collection: String
    @Guide(description: "The main place the page is about (a hotel, restaurant, venue or destination name), or an empty string if it is not about a place.")
    var placeName: String
}

/// Apple's on-device model (Apple Intelligence). Returns nil when the model is not available.
@available(iOS 26.0, *)
struct OnDeviceSummarizer: Summarizing {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func summarize(title: String, text: String) async -> ModelDigest? {
        guard Self.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: "You help a read-later app. Summarise web pages factually and briefly, and classify them.")
        let prompt = "Title: \(title)\n\nPage text:\n\(String(text.prefix(5000)))"
        do {
            let response = try await session.respond(to: prompt, generating: PageDigest.self)
            let d = response.content
            let summary = d.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else { return nil }
            let place = d.placeName.trimmingCharacters(in: .whitespacesAndNewlines)
            return ModelDigest(summary: summary,
                               collection: StashCollection(rawValue: d.collection.lowercased().trimmingCharacters(in: .whitespaces)),
                               placeName: place.isEmpty ? nil : place)
        } catch {
            return nil
        }
    }
}
#endif

enum Summarizers {
    /// The on-device model when this phone and OS have it, else nil (the page description is used).
    static func best() -> Summarizing? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceSummarizer.isAvailable { return OnDeviceSummarizer() }
        #endif
        return nil
    }
}

// MARK: - Images

enum ImageFetcher {
    /// Downloads (or, for `demo://` URLs, draws) an image and downsizes it to a JPEG.
    static func jpeg(from url: URL) async -> Data? {
        if url.scheme == "demo" {
            return DemoArt.image(named: url.host ?? "mountain").jpegData(compressionQuality: 0.85)
        }
        guard url.scheme?.hasPrefix("http") == true else { return nil }
        do {
            var req = URLRequest(url: url, timeoutInterval: 15)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                         forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let img = UIImage(data: data) else { return nil }
            return downsized(img, maxWidth: 1000).jpegData(compressionQuality: 0.8)
        } catch {
            return nil
        }
    }

    static func downsized(_ img: UIImage, maxWidth: CGFloat) -> UIImage {
        guard img.size.width > maxWidth else { return img }
        let scale = maxWidth / img.size.width
        let size = CGSize(width: maxWidth, height: (img.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

// MARK: - Places

enum PlaceLocator {
    /// Finds coordinates (and the city) for a place name with MapKit search.
    static func locate(_ place: Place) async -> Place {
        guard !place.hasCoordinate else { return place }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [place.searchQuery, place.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let first = response.mapItems.first else { return place }
            var p = place
            let pm = first.placemark
            p.latitude = pm.coordinate.latitude
            p.longitude = pm.coordinate.longitude
            if p.city == nil {
                let c = [pm.locality, pm.country].compactMap { $0 }.joined(separator: ", ")
                p.city = c.isEmpty ? nil : c
            }
            if p.address == nil {
                let a = [pm.thoroughfare, pm.subThoroughfare, pm.locality].compactMap { $0 }.joined(separator: " ")
                p.address = a.isEmpty ? nil : a
            }
            return p
        } catch {
            return place
        }
    }
}

// MARK: - Reminders

enum ReminderScheduler {
    static let prefix = "stash-remind-"

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(_ item: Item) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [prefix + item.id.uuidString])
        guard let date = item.remindAt, date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Read later"
        content.body = item.title
        if let s = item.summary { content.subtitle = String(s.prefix(90)) }
        content.sound = .default
        content.userInfo = ["itemID": item.id.uuidString]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(identifier: prefix + item.id.uuidString, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        center.add(request)
    }

    static func cancel(_ id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [prefix + id.uuidString])
    }

    /// Makes the pending notifications match the items (after a Share Sheet save or a restore).
    static func resync(_ items: [Item]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            DispatchQueue.main.async { items.forEach(schedule) }
        }
    }

    static func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count, withCompletionHandler: nil)
    }
}
