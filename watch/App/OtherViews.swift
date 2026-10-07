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
                                .navigationTitle(card.tag)
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
    @AppStorage(SettingKey.tipsPerDay) private var tipsPerDay = 2

    var body: some View {
        List {
            Section {
                Picker("每日技巧", selection: $tipsPerDay) {
                    Text("关闭").tag(0)
                    Text("每天 1 条").tag(1)
                    Text("每天 2 条").tag(2)
                    Text("每天 3 条").tag(3)
                }
            } header: {
                Text("主动推送")
            } footer: {
                Text(footer)
            }
            Section {
                Text("共 \(CardLibrary.tips.count) 条技巧，全部离线可用")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .onChange(of: tipsPerDay) { _, _ in
            Task { await Notifier.scheduleTips() }
        }
    }

    private var footer: String {
        let times = Config.tipTimes.prefix(tipsPerDay).sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
            .map { String(format: "%d:%02d", $0.hour, $0.minute) }
        return times.isEmpty ? "不推送技巧提醒" : "每天 " + times.joined(separator: "、") + " 推送"
    }
}
