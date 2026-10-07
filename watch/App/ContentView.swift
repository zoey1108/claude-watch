import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject private var deck: CardDeck
    @Environment(\.scenePhase) private var scenePhase
    @State private var crown = 0.0
    @State private var favoriteToast: Bool?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            CardView(card: deck.current, isFavorite: deck.isFavorite)
                .id(deck.current.id + "\(deck.position)")
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture {
                    WKInterfaceDevice.current().play(.click)
                    withAnimation(.snappy(duration: 0.25)) { deck.next() }
                }
                .onLongPressGesture { toggleFavorite() }
                // 转表冠翻看刚才看过的卡片
                .focusable()
                .digitalCrownRotation($crown, from: 0, through: Double(max(deck.history.count - 1, 1)),
                                      by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
                .onChange(of: crown) { _, value in
                    let target = min(max(Int(value.rounded()), 0), deck.history.count - 1)
                    if target != deck.position { withAnimation(.snappy(duration: 0.2)) { deck.position = target } }
                }
                .onChange(of: deck.position) { _, position in
                    if Int(crown.rounded()) != position { crown = Double(position) }
                }
                .userActivity("NSUserActivityTypeBrowsingWeb", isActive: deck.current.url != nil) { activity in
                    // 新闻卡片可通过「接力」在 iPhone 上打开原文
                    activity.webpageURL = deck.current.url.flatMap(URL.init(string:))
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink { FavoritesView() } label: { Image(systemName: "star") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                    }
                }
                .overlay {
                    if let added = favoriteToast {
                        FavoriteToast(added: added)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
        }
        .task {
            await deck.refreshNews()
            await Notifier.requestAuthorization()
            await Notifier.scheduleTips()
            BackgroundRefresh.schedule()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await deck.refreshNews() }
        }
    }

    /// 长按收藏 / 取消收藏，弹出提示约 1 秒后消失
    private func toggleFavorite() {
        let added = !deck.isFavorite
        deck.toggleFavorite(deck.current)
        WKInterfaceDevice.current().play(added ? .success : .directionDown)
        withAnimation(.spring(duration: 0.3)) { favoriteToast = added }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { favoriteToast = nil }
        }
    }
}

struct FavoriteToast: View {
    let added: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: added ? "star.fill" : "star.slash")
                .foregroundStyle(added ? Color.yellow : Color.secondary)
            Text(added ? "已收藏" : "已取消收藏")
        }
        .font(.system(.body, design: .rounded).weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
    }
}

struct CardView: View {
    let card: Card
    var isFavorite = false
    var showHint = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: card.isNews ? "newspaper.fill" : "lightbulb.fill")
                Text(card.isNews ? "新闻" : card.tag)
                if let date = card.shortDate, card.isNews {
                    Text("· \(date)").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(card.isNews ? Color.coral : Color.sand)
            .lineLimit(1)

            Text(card.title)
                .font(.system(.headline, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(card.body)
                .font(.system(.footnote))
                .foregroundStyle(.primary.opacity(0.85))
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            if showHint {
                Text(card.url != nil ? "轻点换一条 · 接力到 iPhone 看原文"
                     : isFavorite ? "轻点换一条 · 长按取消收藏" : "轻点换一条 · 长按收藏")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 4)
    }
}

extension Color {
    static let coral = Color(red: 0.85, green: 0.47, blue: 0.34)
    static let sand = Color(red: 0.86, green: 0.78, blue: 0.66)
}
