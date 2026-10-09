import SwiftUI
import UserNotifications

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
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var nextDate: Date?
    @State private var testSent = false

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
                Label(statusText, systemImage: status == .denied ? "bell.slash" : "bell")
                    .foregroundStyle(status == .denied ? Color.orange : Color.primary)
                    .font(.footnote)
                if status == .denied {
                    Text("在 iPhone 的「Watch」App →「通知」里找到「AI 一点通」打开")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if let nextDate {
                    Text("下一条：" + nextDate.formatted(.dateTime.month().day().hour().minute()))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button(testSent ? "已安排，放下手腕等 5 秒" : "发一条测试提醒") {
                    Task {
                        await Notifier.requestAuthorization()
                        await Notifier.sendTest()
                        testSent = true
                        await refresh()
                    }
                }
                .disabled(status == .denied)
            } header: {
                Text("提醒状态")
            }
            Section {
                Text("共 \(CardLibrary.tips.count) 条技巧，全部离线可用")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .task { await refresh() }
        .onChange(of: tipsPerDay) { _, _ in
            Task {
                await Notifier.scheduleTips()
                await refresh()
            }
        }
    }

    private func refresh() async {
        status = await Notifier.authorizationStatus()
        nextDate = await Notifier.nextTipDate()
    }

    private var statusText: String {
        switch status {
        case .denied: "通知已关闭"
        case .notDetermined: "还没有授权通知"
        default: "通知已开启"
        }
    }

    private var footer: String {
        let times = Config.tipTimes.prefix(tipsPerDay).sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
            .map { String(format: "%d:%02d", $0.hour, $0.minute) }
        return times.isEmpty ? "不推送技巧提醒" : "每天 " + times.joined(separator: "、") + " 推送"
    }
}
