import SwiftUI
import StashKit

/// The compact "Save to Stash" card shown by the Share Extension (and in the app's how-to screen).
struct ShareCardView: View {
    let title: String
    let host: String
    let image: UIImage?
    let summary: String?
    let loading: Bool
    let collection: StashCollection?
    @Binding var reminder: ReminderPreset?
    let saved: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GlassIconButton(systemImage: "xmark", size: 40, iconSize: 15, label: "Cancel", identifier: "shareCancel", action: onCancel)
                Spacer()
                HStack(spacing: 8) {
                    AppGlyph(size: 22)
                    Text("Save to Stash").font(.scaled(16, weight: .semibold))
                }
                Spacer()
                GlassIconButton(systemImage: "checkmark", size: 40, iconSize: 16, label: "Save", identifier: "shareSave", filled: true, action: onSave)
            }

            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Theme.field
                            Image(systemName: "link").font(.scaled(24, weight: .semibold)).foregroundStyle(Theme.ink3)
                        }
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.scaled(15.5, weight: .semibold)).lineLimit(3)
                    if loading {
                        SummaryLabel(text: "Summarizing\u{2026}")
                        ShimmerLines()
                    } else if let summary, !summary.isEmpty {
                        SummaryLabel()
                        Text(summary).font(.scaled(13.5)).foregroundStyle(Theme.ink2).lineLimit(4)
                    } else {
                        HStack(spacing: 6) {
                            SiteBadge(host: host)
                            Text(host).font(.scaled(13)).foregroundStyle(Theme.ink3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardEdge))

            HStack(spacing: 8) {
                Text("Collection").frame(width: 76, alignment: .leading)
                if let collection, collection != .none {
                    CollectionPill(collection: collection, auto: true)
                } else {
                    Text(loading ? "Sorting\u{2026}" : "Sorted after saving").foregroundStyle(Theme.ink3)
                }
            }
            .font(.scaled(13.5))
            .foregroundStyle(Theme.ink2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Read later").frame(width: 76, alignment: .leading)
                FlowLayout(spacing: 6) {
                    ChipButton(title: "Not now", selected: reminder == nil, selectedFill: Theme.reminder) { reminder = nil }
                    ForEach(ReminderPreset.allCases) { p in
                        ChipButton(title: p.label, selected: reminder == p, selectedFill: Theme.reminder) { reminder = p }
                            .accessibilityIdentifier("shareRemind-\(p.label)")
                    }
                }
            }
            .font(.scaled(13.5))
            .foregroundStyle(Theme.ink2)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.icloud").foregroundStyle(Theme.offline)
                Text("An offline copy of the article will be saved too.").foregroundStyle(Theme.ink2)
            }
            .font(.scaled(13.5))
        }
        .padding(14)
        .foregroundStyle(Theme.ink)
        .background(Color(hex: "#242426").opacity(0.96), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.1)))
        .overlay {
            if saved {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color(hex: "#242426"))
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.scaled(28, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 62, height: 62)
                            .background(Theme.offline, in: Circle())
                        Text("Saved to Stash").font(.scaled(16, weight: .semibold))
                    }
                }
                .transition(.opacity)
                .accessibilityIdentifier("shareSaved")
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shareCard")
    }
}

/// The Stash app glyph: four rounded tiles in a staggered grid.
struct AppGlyph: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#3A3A3C"), Color(hex: "#1C1C1E")], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            Canvas { ctx, sz in
                let k = sz.width / 24
                for r in [CGRect(x: 5, y: 4, width: 6, height: 8), CGRect(x: 13, y: 4, width: 6, height: 5),
                          CGRect(x: 5, y: 14, width: 6, height: 6), CGRect(x: 13, y: 11, width: 6, height: 9)] {
                    let rect = CGRect(x: r.minX * k, y: r.minY * k, width: r.width * k, height: r.height * k)
                    ctx.stroke(Path(roundedRect: rect, cornerRadius: 1.6 * k), with: .color(.white), lineWidth: 1.6 * k)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
