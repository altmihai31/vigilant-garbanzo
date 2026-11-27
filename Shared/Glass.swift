import SwiftUI

/// Liquid Glass on iOS 26 (`glassEffect`), a material fallback on older systems.
struct GlassBackground<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color? = nil
    var interactive = true

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
    #endif

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.06), .white.opacity(0.12)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                    if let tint { shape.fill(tint) }
                }
            }
            .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

extension View {
    func glass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = true) -> some View {
        modifier(GlassBackground(shape: shape, tint: tint, interactive: interactive))
    }
}

/// A round glass button with an SF Symbol, sized per the spec (58 / 66 / 52 pt).
struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 52
    var iconSize: CGFloat = 20
    var label: String
    var identifier: String? = nil
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(filled ? Color.black : Color.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(GlassOrFill(filled: filled))
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? label)
    }
}

/// Save buttons are solid white circles; everything else is glass.
struct GlassOrFill: ViewModifier {
    let filled: Bool
    func body(content: Content) -> some View {
        if filled {
            content.background(Theme.ink, in: Circle())
        } else {
            content.glass(in: Circle())
        }
    }
}
