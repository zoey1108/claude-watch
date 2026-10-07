import Foundation
import UserNotifications

/// 主动推送：每日技巧用手表本地的定时通知，不联网。
enum Notifier {
    private static let center = UNUserNotificationCenter.current()
    private static let tipPrefix = "tip-"

    static func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// 重新排未来 7 天的技巧提醒（本地通知上限 64 条，7 天 × 3 条足够）
    static func scheduleTips() async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:
            pending.map(\.identifier).filter { $0.hasPrefix(tipPrefix) })

        let perDay = UserDefaults.standard.object(forKey: SettingKey.tipsPerDay) as? Int ?? 2
        guard perDay > 0 else { return }

        let times = Config.tipTimes.prefix(perDay)
        var tips = CardLibrary.tips.shuffled()
        let calendar = Calendar.current
        let now = Date()

        for day in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: day, to: now) else { continue }
            for time in times {
                var comps = calendar.dateComponents([.year, .month, .day], from: date)
                comps.hour = time.hour
                comps.minute = time.minute
                guard let fire = calendar.date(from: comps), fire > now else { continue }
                let card = tips.popLast() ?? CardLibrary.randomTip()
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "\(tipPrefix)\(card.id)-\(day)-\(time.hour)",
                                                    content: content(for: card), trigger: trigger)
                try? await center.add(request)
            }
        }
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
