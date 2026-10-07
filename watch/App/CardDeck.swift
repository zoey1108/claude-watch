import Foundation
import SwiftUI

/// 牌堆：决定下一张出什么，记录看过的历史和收藏。全部离线。
@MainActor
final class CardDeck: ObservableObject {
    static let shared = CardDeck()

    @Published private(set) var history: [Card] = []
    @Published var position = 0
    @Published private(set) var favorites: [Card]

    private var seen: Set<String>
    private let defaults = UserDefaults.standard

    var current: Card { history.indices.contains(position) ? history[position] : CardLibrary.fallback }
    var isFavorite: Bool { favorites.contains { $0.id == current.id } }

    private init() {
        seen = Set(defaults.stringArray(forKey: "seen") ?? [])
        favorites = Self.load("favorites") ?? []
        next()
    }

    // MARK: 抽卡

    /// 随机抽一条没看过的技巧，一轮看完再重新洗牌
    func next() {
        let tips = CardLibrary.tips
        var pool = tips.filter { !seen.contains($0.id) && $0.id != current.id }
        if pool.isEmpty {
            seen.subtract(tips.map(\.id))
            pool = tips.filter { $0.id != current.id }
        }
        append(pool.randomElement() ?? CardLibrary.randomTip())
    }

    func show(id: String) {
        if let card = (favorites + CardLibrary.tips).first(where: { $0.id == id }) {
            append(card)
        }
    }

    func handle(_ url: URL) {
        guard url.scheme == "claudetap", url.host == "card" else { return }
        show(id: url.lastPathComponent)
    }

    private func append(_ card: Card) {
        history.append(card)
        if history.count > 50 { history.removeFirst(history.count - 50) }
        position = history.count - 1
        seen.insert(card.id)
        defaults.set(Array(seen), forKey: "seen")
    }

    // MARK: 收藏

    func toggleFavorite(_ card: Card) {
        if let i = favorites.firstIndex(where: { $0.id == card.id }) {
            favorites.remove(at: i)
        } else {
            favorites.insert(card, at: 0)
        }
        Self.save(favorites, "favorites")
    }

    func removeFavorites(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        Self.save(favorites, "favorites")
    }

    // MARK: 存储

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
