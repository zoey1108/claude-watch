import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var deck: CardDeck

    var body: some View {
        Group {
            if deck.favorites.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "star").font(.title2).foregroundStyle(.secondary)
                    Text("还没有收藏").font(.headline)
                    Text("在卡片上长按即可收藏").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(deck.favorites) { card in
                        NavigationLink {
                            ScrollView { CardView(card: card, showHint: false) }
                                .navigationTitle(card.isNews ? "新闻" : card.tag)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.title).font(.headline).lineLimit(1)
                                Text(card.body).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                    .onDelete { deck.removeFavorites(at: $0) }
                }
            }
        }
        .navigationTitle("收藏")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var deck: CardDeck
    @AppStorage(SettingKey.tipsPerDay) private var tipsPerDay = 2
    @AppStorage(SettingKey.newsAlerts) private var newsAlerts = true
    @State private var checking = false

    var body: some View {
        List {
            Section("主动推送") {
                Picker("每日技巧", selection: $tipsPerDay) {
                    Text("关闭").tag(0)
                    Text("每天 1 条").tag(1)
                    Text("每天 2 条").tag(2)
                    Text("每天 3 条").tag(3)
                }
                Toggle("新闻提醒", isOn: $newsAlerts)
            }
            Section {
                Button {
                    checking = true
                    Task {
                        await deck.refreshNews()
                        checking = false
                    }
                } label: {
                    HStack {
                        Text("检查新闻")
                        Spacer()
                        if checking { ProgressView().frame(width: 20) }
                    }
                }
                .disabled(checking)
            } footer: {
                Text(statusText)
            }
            Section {
                Text("技巧 \(CardLibrary.tips.count) 条 · 新闻 \(deck.news.count) 条")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .onChange(of: tipsPerDay) { _, _ in
            Task { await Notifier.scheduleTips() }
        }
    }

    private var statusText: String {
        guard let date = deck.lastRefresh else { return "还没有拉取过新闻" }
        return "上次更新：" + date.formatted(.relative(presentation: .named))
    }
}
