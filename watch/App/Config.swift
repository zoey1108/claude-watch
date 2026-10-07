import Foundation

enum Config {
    /// 新闻源：GitHub Actions 每 3 小时更新一次，发布在 GitHub Pages 上
    static let newsURL = URL(string: "https://zoey1108.github.io/claude-watch/cards.json")!

    /// 后台检查新闻的间隔（系统会根据电量和使用情况适当推迟）
    static let refreshInterval: TimeInterval = 60 * 60

    /// 每日技巧提醒的时间点，按「每天几条」取前 N 个
    static let tipTimes: [(hour: Int, minute: Int)] = [(9, 30), (20, 30), (13, 0)]
}

enum SettingKey {
    static let tipsPerDay = "tipsPerDay"     // 0 表示关闭
    static let newsAlerts = "newsAlerts"
}
