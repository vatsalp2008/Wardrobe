import SwiftUI

/// Central design tokens (spec §7.2). Build once, reuse everywhere.
/// Colors adapt to light/dark via the asset catalog where appropriate; the brand
/// tokens here are fixed hex values from the spec.
enum DS {

    // MARK: - Color
    enum Colors {
        /// #1A56A0 — buttons, active states, key actions.
        static let primary = Color(hex: "#1A56A0")
        /// #E6F1FB — card backgrounds, info states.
        static let accent = Color(hex: "#E6F1FB")

        /// Adaptive background: #F9F9F9 light / #1A1A1A dark.
        static let background = Color(light: Color(hex: "#F9F9F9"), dark: Color(hex: "#1A1A1A"))
        /// Adaptive surface for cards sitting on the background.
        static let surface = Color(light: .white, dark: Color(hex: "#2A2A2A"))

        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
    }

    // MARK: - Typography (SF Pro)
    enum Typography {
        /// SF Pro Display, Bold, 28pt — screen titles.
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        /// Section headers.
        static let headline = Font.system(size: 20, weight: .semibold, design: .default)
        /// SF Pro Text, Regular, 16pt — body copy.
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        /// SF Pro Text, Regular, 13pt — labels, metadata.
        static let caption = Font.system(size: 13, weight: .regular, design: .default)
    }

    // MARK: - Spacing (8pt base grid)
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner radius
    enum Radius {
        static let card: CGFloat = 12
        static let chip: CGFloat = 8
        static let sheet: CGFloat = 24
    }

    // MARK: - Animation
    enum Motion {
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
}

private extension Color {
    /// Builds a Color that resolves differently for light and dark appearance.
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
