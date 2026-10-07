import Foundation
import SwiftUI

/// 牌堆：决定下一张出什么，记录看过的历史和收藏。
@MainActor
final class CardDeck: ObservableObject {
    static let shared = CardDeck()

    @Published private(set) var history: [Card] = []
    @Published var position = 0
    @Published private(set) var favorites: [Card]
    @Published private(set) var news: [Card]
    @Published private(set) var lastRefresh: Date?

    private var seen: Set<String>
    private let defaults = UserDefaults.standard

    var current: Card { history.indices.contains(position) ? history[position] : CardLibrary.fallback }
    var isFavorite: Bool { favorites.contains { $0.id == current.id } }

    private init() {
        seen = Set(defaults.stringArray(forKey: "seen") ?? [])
        news = Self.load("news") ?? []
        favorites = Self.load("favorites") ?? []
        lastRefresh = defaults.object(forKey: "lastRefresh") as? Date
        next()
    }

    // MARK: 抽卡

    /// 没看过的新闻优先（最新的先出），否则随机抽一条没看过的技巧
    func next() {
        append(news.first { !seen.contains($0.id) } ?? pickTip())
    }

    func show(id: String) {
        if let card = (news + favorites + CardLibrary.tips).first(where: { $0.id == id }) {
            append(card)
        }
    }

    func handle(_ url: URL) {
        guard url.scheme == "claudetap", url.host == "card" else { return }
        show(id: url.lastPathComponent)
    }

    private func pickTip() -> Card {
        let tips = CardLibrary.tips
        var pool = tips.filter { !seen.contains($0.id) && $0.id != current.id }
        if pool.isEmpty {
            // 一轮看完，重新洗牌
            seen.subtract(tips.map(\.id))
            pool = tips.filter { $0.id != current.id }
        }
        return pool.randomElement() ?? CardLibrary.randomTip()
    }

    private func append(_ card: Card) {
        history.append(card)
        if history.count > 50 { history.removeFirst(history.count - 50) }
        position = history.count - 1
        seen.insert(card.id)
        defaults.set(Array(seen.suffix(400)), forKey: "seen")
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

    // MARK: 新闻

    /// 拉取最新新闻，返回这次新出现的条目（首次安装不算新，避免一下子弹一堆通知）
    @discardableResult
    func refreshNews() async -> [Card] {
        guard let fetched = try? await NewsService.fetch() else { return [] }
        let isFirstLoad = news.isEmpty && lastRefresh == nil
        let known = Set(news.map(\.id))
        let fresh = fetched.filter { !known.contains($0.id) }
        news = fetched
        lastRefresh = Date()
        Self.save(news, "news")
        defaults.set(lastRefresh, forKey: "lastRefresh")
        if isFirstLoad {
            // 首次只把最新 3 条当未读，其余直接标为看过
            seen.formUnion(fetched.dropFirst(3).map(\.id))
            return []
        }
        return fresh
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

enum NewsService {
    private struct Feed: Decodable { let cards: [Card] }

    static func fetch() async throws -> [Card] {
        let request = URLRequest(url: Config.newsURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Feed.self, from: data).cards
    }
}
