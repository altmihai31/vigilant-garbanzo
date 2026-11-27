import SwiftUI
import UserNotifications
import StashKit

extension Notification.Name {
    static let stashOpenItem = Notification.Name("stashOpenItem")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    /// Tapping a Read later reminder opens the item.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let s = response.notification.request.content.userInfo["itemID"] as? String, let id = UUID(uuidString: s) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .stashOpenItem, object: id)
            }
        }
        completionHandler()
    }
}

@main
struct StashApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let args = ProcessInfo.processInfo.arguments
        _model = StateObject(wrappedValue: AppModel(demo: args.contains("-StashDemo")))
    }

    var body: some Scene {
        WindowGroup {
            DynamicTypeRoot { HomeView() }
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { model.handle(url: $0) }
                .onReceive(NotificationCenter.default.publisher(for: .stashOpenItem)) { note in
                    if let id = note.object as? UUID { model.open(id) }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.becameActive() }
                }
                .task { model.becameActive() }
        }
    }
}

/// Fonts are sized with `Font.scaled`, which reads the Dynamic Type setting when a view is drawn,
/// so the tree is rebuilt when the setting changes. Navigation state lives in AppModel and survives.
struct DynamicTypeRoot<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    @ViewBuilder var content: () -> Content
    var body: some View { content().id(size) }
}
