import SwiftUI
import WidgetKit

struct TipEntry: TimelineEntry {
    let date: Date
    let card: Card
}

/// 表盘 / 智能叠放：每 2 小时换一条技巧
struct TipProvider: TimelineProvider {
    func placeholder(in context: Context) -> TipEntry {
        TipEntry(date: .now, card: CardLibrary.tips.first ?? CardLibrary.fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (TipEntry) -> Void) {
        completion(TipEntry(date: .now, card: CardLibrary.randomTip()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TipEntry>) -> Void) {
        let tips = CardLibrary.tips.shuffled()
        let entries = (0..<12).map { i in
            TipEntry(date: Date().addingTimeInterval(Double(i) * 2 * 3600),
                     card: tips.indices.contains(i) ? tips[i] : CardLibrary.fallback)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TipWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TipEntry

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(CardLibrary.deepLink(for: entry.card))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            Label(entry.card.title, systemImage: "lightbulb")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lightbulb.fill").font(.title3).widgetAccentable()
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Label(entry.card.title, systemImage: "lightbulb.fill")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(entry.card.body)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@main
struct TipWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClaudeTip", provider: TipProvider()) { entry in
            TipWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude 小技巧")
        .description("每 2 小时换一条，点一下打开 App。")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
