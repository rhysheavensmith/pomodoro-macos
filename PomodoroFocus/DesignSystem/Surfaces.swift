import SwiftUI

/// The warm cream→white (light) / warm-dark (dark) canvas shared by every tab.
struct WarmCanvas: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.background(
            (scheme == .dark
                ? LinearGradient(colors: [Theme.Palette.canvasWarmDeep, .black],
                                 startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [Theme.Palette.canvasWarm, .white],
                                 startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        )
    }
}

/// An elevated, softly-shadowed card surface that pops on the warm canvas.
struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(.white.opacity(0.10))
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

extension View {
    func warmCanvas() -> some View { modifier(WarmCanvas()) }
    func card() -> some View { modifier(CardSurface()) }
}

/// Consistent screen header: bold tracked eyebrow + oversized rounded title.
struct ScreenHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(Theme.Palette.focus.opacity(0.75))
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
        }
    }
}
