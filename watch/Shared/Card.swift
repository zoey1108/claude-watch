import Foundation

/// 一张卡片：一条小技巧或一条新闻。手表端与服务端 cards.json 共用这个结构。
struct Card: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case tip, news }

    let id: String
    let type: Kind
    let title: String
    let body: String
    let tag: String
    var url: String? = nil
    var date: String? = nil

    var isNews: Bool { type == .news }

    /// 新闻日期显示成「10月5日」
    var shortDate: String? {
        guard let date, date.count >= 10 else { return nil }
        let parts = date.prefix(10).split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        return "\(m)月\(d)日"
    }
}

enum CardLibrary {
    /// 打包在 App 内的技巧库，离线可用
    static let tips: [Card] = {
        guard let url = Bundle.main.url(forResource: "tips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cards = try? JSONDecoder().decode([Card].self, from: data) else { return [] }
        return cards
    }()

    static let fallback = Card(id: "t000", type: .tip, title: "轻点屏幕",
                               body: "每点一下，换一条 Claude 小技巧或新闻。", tag: "开始")

    static func randomTip() -> Card { tips.randomElement() ?? fallback }

    /// 小组件和通知用的深链：claudetap://card/<id>
    static func deepLink(for card: Card) -> URL {
        URL(string: "claudetap://card/\(card.id)")!
    }
}
