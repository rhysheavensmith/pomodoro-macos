import SwiftUI

/// A single pomodoro tile. The **current** tile is itself the start button: it
/// shows a play glyph and springs on press; all other tiles are non-interactive.
struct TomatoTile: View {
    let tomato: DayTomato
    var size: CGFloat = 30
    /// Non-nil only for the current, startable tile.
    var onPress: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Group {
            if let onPress {
                Button(action: onPress) { tile }
                    .buttonStyle(TomatoPressStyle())
                    .help("Start this pomodoro")
            } else {
                tile
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard tomato.isCurrent, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(onPress != nil ? [.isButton] : [])
    }

    private var tile: some View {
        ZStack {
            if tomato.taskTitle == nil {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.35),
                                  style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
            } else {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Palette.focusSoft, Theme.Palette.focus],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: Theme.Palette.focus.opacity(0.35), radius: 2.5, y: 1.5)
                    .overlay(alignment: .top) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: size * 0.30))
                            .foregroundStyle(Theme.Palette.leaf)
                            .rotationEffect(.degrees(-30))
                            .offset(x: size * 0.10, y: -size * 0.10)
                    }
                if tomato.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .heavy))
                        .foregroundStyle(.white)
                } else if onPress != nil {
                    // The current, pressable tomato IS the start button.
                    Image(systemName: "play.fill")
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                }
            }
            if tomato.isCurrent {
                Circle()
                    .strokeBorder(Theme.Palette.streak, lineWidth: 2.5)
                    .frame(width: size + 9, height: size + 9)
                    .scaleEffect(pulse ? 1.05 : 0.97)
                    .opacity(pulse ? 0.6 : 1)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }

    private var accessibilityText: String {
        guard let title = tomato.taskTitle else { return "Empty pomodoro slot" }
        if tomato.isDone { return "Pomodoro for \(title), done" }
        if onPress != nil { return "Start pomodoro for \(title)" }
        return "Pomodoro for \(title), planned"
    }
}

/// Springy scale-down on press for a tomato start button.
struct TomatoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.45), value: configuration.isPressed)
    }
}
