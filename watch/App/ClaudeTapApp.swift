import SwiftUI
import UserNotifications
import WatchKit

@main
struct ClaudeTapApp: App {
    @WKApplicationDelegateAdaptor private var delegate: AppDelegate
    @StateObject private var deck = CardDeck.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deck)
                .onOpenURL { deck.handle($0) }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) {
            await BackgroundRefresh.run()
        }
    }
}

final class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
    }

    // App 在前台时也显示横幅
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // 点通知进 App，直接显示那张卡片
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["cardID"] as? String else { return }
        await MainActor.run { CardDeck.shared.show(id: id) }
    }
}
