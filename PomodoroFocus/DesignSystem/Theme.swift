import SwiftUI

/// Centralized design tokens. Every surface (menu bar, focus shield, plan,
/// dashboard) reads from here so the app stays visually consistent.
///
/// Visual language: *Bold/Exaggerated Minimalism* — the timer is a huge, calm
/// centerpiece with generous negative space. Color is never the only signal:
/// each timer phase also carries a label + SF Symbol (colorblind-safe).
enum Theme {

    // MARK: - Brand / semantic state colors

    enum Palette {
        /// Focus / work state.
        static let focus = Color(hex: 0xDC2626)
        static let focusSoft = Color(hex: 0xEF4444)
        /// Break state.
        static let breakColor = Color(hex: 0x059669)
        static let breakSoft = Color(hex: 0x10B981)
        /// Accent (matches break green per the approved design).
        static let accent = Color(hex: 0x059669)
        /// Deep slate, used behind the always-on-top Focus Shield.
        static let slate = Color(hex: 0x0F172A)
        /// Warm amber for "streak at risk" / warnings.
        static let warning = Color(hex: 0xD97706)
        /// Gold used for streak flames / milestones.
        static let streak = Color(hex: 0xF59E0B)
        /// Warm canvas + ribbon tones for the "day in pomodoros" timeline.
        static let canvasWarm = Color(hex: 0xFFF6F2)
        static let canvasWarmDeep = Color(hex: 0x17110F)
        static let ribbonWarm = Color(hex: 0xFBEAE1)
        static let leaf = Color(hex: 0x16A34A)

        /// The semantic color for a given timer phase.
        /// NOTE: always pair with a label/icon — never rely on color alone.
        static func color(for phase: TimerPhase) -> Color {
            switch phase {
            case .idle, .paused:
                return .secondary
            case .running:
                return focus
            case .shortBreak, .longBreak:
                return breakColor
            }
        }
    }

    // MARK: - Spacing scale (4 / 8 / 12 / 16 / 24 / 32 / 48)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner radii

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Typography (all native: SF Pro, SF Pro Rounded, New York serif)

    enum Typography {
        /// Giant countdown — rounded + tabular figures so digits never shift width.
        static func timer(size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
        }
        /// Compact countdown shown in the menu bar.
        static let menuBarTime = Font.system(size: 13, weight: .semibold, design: .rounded)
            .monospacedDigit()
        static let titleRounded = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headlineRounded = Font.system(.headline, design: .rounded)
        /// Reflective "Insight of the day" copy — Apple's system serif (New York).
        static let insight = Font.system(.title3, design: .serif)
        static let insightCaption = Font.system(.subheadline, design: .serif)
        /// Big numbers on the dashboard stat cards.
        static let statNumber = Font.system(.largeTitle, design: .rounded).weight(.bold)
            .monospacedDigit()
    }

    // MARK: - Animation tokens (150–300ms springs; respect reduced-motion)

    enum Motion {
        static let quick = Animation.spring(response: 0.25, dampingFraction: 0.85)
        static let gentle = Animation.spring(response: 0.4, dampingFraction: 0.9)
        static let celebrate = Animation.spring(response: 0.45, dampingFraction: 0.6)
    }
}

extension Color {
    /// Build a color from a 0xRRGGBB literal.
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
