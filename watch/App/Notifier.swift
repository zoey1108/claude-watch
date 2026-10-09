import Foundation
import UserNotifications
import WatchKit

/// 主动推送：每日技巧用手表本地的定时通知，不联网。
enum Notifier {
    private static let center = UNUserNotificationCenter.current()
    private static let tipPrefix = "tip-"
    /// 系统最多保留 64 条待发通知，留几条余量
    private static let maxPending = 60

    static func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 下一条技巧提醒的时间，没有排上则为 nil
    static func nextTipDate() async -> Date? {
        await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(tipPrefix) }
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
            .min()
    }

    /// 重新排技巧提醒：按每天条数尽量排满（每天 2 条约 30 天），并由后台刷新每天续排
    static func scheduleTips() async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:
            pending.map(\.identifier).filter { $0.hasPrefix(tipPrefix) })

        let perDay = UserDefaults.standard.object(forKey: SettingKey.tipsPerDay) as? Int ?? 2
        guard perDay > 0 else { return }

        let times = Config.tipTimes.prefix(perDay)
        let days = min(maxPending / perDay, 30)
        var tips = CardLibrary.tips.shuffled()
        let calendar = Calendar.current
        let now = Date()

        for day in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: day, to: now) else { continue }
            for time in times {
                var comps = calendar.dateComponents([.year, .month, .day], from: date)
                comps.hour = time.hour
                comps.minute = time.minute
                guard let fire = calendar.date(from: comps), fire > now else { continue }
                if tips.isEmpty { tips = CardLibrary.tips.shuffled() }
                let card = tips.removeLast()
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "\(tipPrefix)\(card.id)-\(day)-\(time.hour)",
                                                    content: content(for: card), trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    /// 5 秒后发一条测试提醒（放下手腕才能看到通知效果）
    static func sendTest() async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)",
                                            content: content(for: CardLibrary.randomTip()), trigger: trigger)
        try? await center.add(request)
    }

    private static func content(for card: Card) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = card.title
        content.subtitle = "AI 小技巧 · \(card.tag)"
        content.body = card.body
        content.sound = .default
        content.userInfo = ["cardID": card.id]
        return content
    }
}

/// 后台刷新：每天醒来一次续排提醒，不打开 App 也不会断
enum TipRefresh {
    static let id = "tip-refresh"

    @MainActor
    static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(24 * 3600),
            userInfo: id as NSString) { _ in }
    }

    @MainActor
    static func run() async {
        schedule()
        await Notifier.scheduleTips()
    }
}
