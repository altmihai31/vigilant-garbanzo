import SwiftUI
import UIKit
import StashKit

extension Color {
    init(hex: String, opacity: Double = 1) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255, opacity: opacity)
    }
}

/// Design tokens from the spec's design system table. Stash is dark only.
enum Theme {
    static let background = Color.black  // near-black like the iOS 27 Siri app
    static let card = Color(hex: "#18181A")
    static let cardEdge = Color.white.opacity(0.09)
    static let detail = Color.black
    static let sheet = Color(hex: "#1C1C1E")
    static let field = Color(hex: "#2C2C2E")
    static let reader = Color(hex: "#151516")
    static let ink = Color(hex: "#F5F5F7")
    static let ink2 = Color(hex: "#A1A1A6")
    static let ink3 = Color(hex: "#8E8E93")  // 5.0:1 on the card colour
    static let accent = Color(hex: "#5EA2FF")
    static let reminder = Color(hex: "#FF9F0A")
    static let summary = Color(hex: "#BF9BFF")
    static let collectionInk = Color(hex: "#D9C6FF")
    static let offline = Color(hex: "#30D158")
    static let pin = Color(hex: "#FF6B5E")
    static let readerInk = Color(hex: "#E8E4DC")

    static let cardRadius: CGFloat = 26
    static let margin: CGFloat = 16
    static let gap: CGFloat = 12
}

/// A small coloured square with the site's first letter, standing in for a favicon.
struct SiteBadge: View {
    let host: String
    var size: CGFloat = 16

    static let palette = ["#c8102e", "#5200ff", "#e4002b", "#2f6fde", "#111111", "#e5202e", "#1d1d1f", "#f5a623", "#0a7d5a", "#8e44ad"]

    var body: some View {
        let letter = host.first.map { String($0).uppercased() } ?? "•"
        let idx = abs(host.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }) % Self.palette.count
        RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
            .fill(Color(hex: Self.palette[idx]))
            .frame(width: size, height: size)
            .overlay(Text(letter).font(.system(size: size * 0.62, weight: .heavy)).foregroundStyle(.white))
            .accessibilityHidden(true)
    }
}

/// "Summary from the page" label with the sparkle.
struct SummaryLabel: View {
    var text = "Summary from the page"
    var body: some View {
        Label(text, systemImage: "sparkle")
            .font(.scaled(12.5, weight: .semibold))
            .foregroundStyle(Theme.summary)
            .labelStyle(TightLabelStyle(spacing: 5))
    }
}

struct TightLabelStyle: LabelStyle {
    var spacing: CGFloat = 6
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

/// Grey shimmer lines shown while a summary is being written.
struct ShimmerLines: View {
    var lines = 2
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<lines, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Theme.field, Color(hex: "#3A3A3C"), Theme.field],
                                         startPoint: UnitPoint(x: phase, y: 0.5), endPoint: UnitPoint(x: phase + 1, y: 0.5)))
                    .frame(height: 11)
                    .frame(maxWidth: i == lines - 1 ? 140 : .infinity, alignment: .leading)
            }
        }
        .onAppear {
            // Reduce Motion: keep the placeholder still instead of sweeping.
            guard !reduceMotion else { phase = 0; return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase = 1 }
        }
        .accessibilityLabel("Summarizing")
    }
}

/// The purple collection pill, optionally with the AUTO tag.
struct CollectionPill: View {
    let collection: StashCollection
    var auto = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: collection.symbol).font(.scaled(12, weight: .semibold))
            Text(collection.name).font(.scaled(14, weight: .semibold))
            if auto {
                Text("AUTO").font(.scaled(10, weight: .bold)).foregroundStyle(Theme.summary)
            }
        }
        .padding(.vertical, 7)
        .padding(.leading, 10)
        .padding(.trailing, 13)
        .background(Theme.summary.opacity(0.14), in: Capsule())
        .foregroundStyle(Theme.collectionInk)
    }
}

/// Pill-shaped choice chip (Read later presets, tags).
struct ChipButton: View {
    let title: String
    var selected = false
    var selectedFill: Color = Theme.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.scaled(13.5, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? selectedFill : Theme.field, in: Capsule())
                .foregroundStyle(selected ? Color.black : Theme.ink2)
                // 44 pt tap target (HIG) without changing the drawn chip.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Wraps children onto new lines, for tags and chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

extension Font {
    /// A system font at the design size that grows and shrinks with the person's Dynamic Type setting
    /// (scaled like Body, capped so the two-column grid stays usable).
    static func scaled(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let s = UIFontMetrics(forTextStyle: .body).scaledValue(for: size)
        return .system(size: min(s, size * 1.8), weight: weight, design: design)
    }
}

/// Soft, low-saturation glow over black, after the iOS 27 Siri app: pink, purple and blue at the top,
/// a faint warm light at the bottom. Kept dim so cards and text stay the focus.
struct AmbientGlow: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.black
                RadialGradient(colors: [Color(hex: "#8E6BE0").opacity(0.20), .clear], center: UnitPoint(x: 0.15, y: -0.02),
                               startRadius: 0, endRadius: w * 0.85)
                RadialGradient(colors: [Color(hex: "#2E4A9E").opacity(0.26), .clear], center: UnitPoint(x: 0.85, y: 0.0),
                               startRadius: 0, endRadius: w * 0.8)
                RadialGradient(colors: [Color(hex: "#E36BB0").opacity(0.10), .clear], center: UnitPoint(x: 0.5, y: 0.08),
                               startRadius: 0, endRadius: w * 0.6)
                RadialGradient(colors: [Color(hex: "#F0A060").opacity(0.08), .clear], center: UnitPoint(x: 0.5, y: 1.05),
                               startRadius: 0, endRadius: max(w, h * 0.35))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
