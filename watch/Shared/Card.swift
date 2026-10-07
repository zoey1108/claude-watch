import Foundation

/// 一张技巧卡片
struct Card: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let tag: String
}

enum CardLibrary {
    /// 打包在 App 内的技巧库，离线可用
    static let tips: [Card] = {
        guard let url = Bundle.main.url(forResource: "tips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cards = try? JSONDecoder().decode([Card].self, from: data) else { return [] }
        return cards
    }()

    static let fallback = Card(id: "t000", title: "轻点屏幕",
                               body: "每点一下，换一条 AI 小技巧。", tag: "开始")

    static func randomTip() -> Card { tips.randomElement() ?? fallback }

    /// 小组件和通知用的深链：claudetap://card/<id>
    static func deepLink(for card: Card) -> URL {
        URL(string: "claudetap://card/\(card.id)")!
    }
}
