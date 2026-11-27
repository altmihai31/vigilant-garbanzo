import SwiftUI
import StashKit

/// One card in the home grid.
struct CardView: View {
    @EnvironmentObject var model: AppModel
    let item: Item

    var body: some View {
        let image = model.image(for: item)
        VStack(alignment: .leading, spacing: 6) {
            if let image {
                Color.clear
                    .aspectRatio(16 / 11, contentMode: .fit)
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, -6)
                    .padding(.top, -6)
                    .padding(.bottom, 6)
            }

            HStack(spacing: 7) {
                if item.isUnread {
                    Circle().fill(Theme.accent).frame(width: 8, height: 8)
                        .shadow(color: Theme.accent.opacity(0.6), radius: 4)
                        .accessibilityLabel("Unread")
                }
                Text(DateText.dateLine(for: item.createdAt))
                    .font(.scaled(15))
                    .foregroundStyle(Theme.ink.opacity(0.92))
                if item.hasUpcomingReminder() {
                    Image(systemName: "bell.fill").font(.scaled(12)).foregroundStyle(Theme.reminder)
                        .accessibilityLabel("Reminder set")
                }
            }
            .padding(.trailing, image == nil ? 26 : 0)

            Text(item.title)
                .font(.scaled(21, weight: .heavy))
                .tracking(-0.35)
                .lineSpacing(-1)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if item.kind == .note {
                if !item.checklist.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(item.checklist) { entry in
                            ChecklistRow(entry: entry, size: 15, font: 14.5)
                        }
                    }
                    .padding(.top, 6)
                } else if let body = item.body {
                    Text(body).font(.scaled(15)).foregroundStyle(Theme.ink2).lineLimit(6).padding(.top, 4)
                }
            } else if item.processingState == .pending && item.summary == nil {
                ShimmerLines().padding(.top, 6)
            } else if let s = item.summary {
                Text(s).font(.scaled(15)).foregroundStyle(Theme.ink2).lineLimit(6).padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let city = item.place?.city ?? item.place?.name {
                HStack(spacing: 5) {
                    Image(systemName: "mappin").font(.scaled(11, weight: .bold)).foregroundStyle(Theme.pin)
                    Text(city).font(.scaled(13)).foregroundStyle(Theme.ink2).lineLimit(1)
                }
                .padding(.top, 6)
            }

            if item.kind == .link {
                HStack(spacing: 6) {
                    SiteBadge(host: item.siteLabel)
                    Text(item.siteLabel).font(.scaled(12.5)).foregroundStyle(Theme.ink3).lineLimit(1).truncationMode(.tail)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 1))
        .overlay(alignment: .topTrailing) { kindIcon(onImage: image != nil) }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    }

    private func kindIcon(onImage: Bool) -> some View {
        Image(systemName: item.kind == .note ? "text.alignleft" : (item.collection == .none ? "link" : item.collection.symbol))
            .font(.scaled(10, weight: .bold))
            .foregroundStyle(onImage ? .white : Theme.ink2)
            .frame(width: 22, height: 22)
            .background(onImage ? AnyShapeStyle(Color.black.opacity(0.45)) : AnyShapeStyle(Color.white.opacity(0.07)), in: Circle())
            .padding(onImage ? 18 : 14)
            .accessibilityHidden(true)
    }
}

struct ChecklistRow: View {
    let entry: ChecklistItem
    var size: CGFloat = 15
    var font: CGFloat = 14.5

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .strokeBorder(Theme.ink3, lineWidth: 1.5)
                .background(Circle().fill(entry.done ? Theme.ink3 : .clear))
                .frame(width: size, height: size)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + font * 0.35 }
            Text(entry.text)
                .font(.scaled(font))
                .strikethrough(entry.done)
                .foregroundStyle(entry.done ? Theme.ink3 : Theme.ink2)
        }
    }
}

struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
