import Foundation

enum Config {
    /// 每日技巧提醒的时间点，按「每天几条」取前 N 个
    static let tipTimes: [(hour: Int, minute: Int)] = [(9, 30), (20, 30), (13, 0)]
}

enum SettingKey {
    static let tipsPerDay = "tipsPerDay"     // 0 表示关闭
}
