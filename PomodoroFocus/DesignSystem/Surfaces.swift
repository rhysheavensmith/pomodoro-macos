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
/// Borderless — separation comes from a soft shadow, not a hard edge.
struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

extension View {
    func warmCanvas() -> some View { modifier(WarmCanvas()) }
    func card() -> some View { modifier(CardSurface()) }
}

/// A warm, on-brand pill button with press feedback — for secondary actions
/// (Edit rhythm, Add focus set, Add break) that should feel part of the design,
/// not a stock system button.
struct SoftPillButtonStyle: ButtonStyle {
    var tint: Color = Theme.Palette.focus
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.20)))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
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
