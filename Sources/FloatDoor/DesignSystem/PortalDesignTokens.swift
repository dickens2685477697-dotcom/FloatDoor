import SwiftUI

/// Shared visual language for Float Door.
///
/// The reference icon set uses a dark, translucent glass surface with cool
/// blue-grey glyphs and a single electric-blue action colour. Keeping the
/// values here makes it possible to tune the whole portal without hunting
/// through individual views.
enum PortalTokens {
    enum Palette {
        /// The blue used for primary actions and active drop targets.
        static let accent = Color(red: 0.25, green: 0.62, blue: 1.0)
        static let accentBright = Color(red: 0.36, green: 0.70, blue: 1.0)
        static let accentDeep = Color(red: 0.08, green: 0.31, blue: 0.72)

        static let canvas = Color(red: 0.035, green: 0.047, blue: 0.067)
        static let glass = Color.white.opacity(0.075)
        static let glassElevated = Color.white.opacity(0.115)
        static let glassPressed = Color.white.opacity(0.16)
        static let glassStroke = Color.white.opacity(0.14)
        static let glassStrokeStrong = Color.white.opacity(0.23)

        static let icon = Color(red: 0.62, green: 0.70, blue: 0.82)
        static let iconHighlight = Color(red: 0.79, green: 0.85, blue: 0.94)
        static let primaryText = Color.white.opacity(0.94)
        static let secondaryText = Color.white.opacity(0.62)
        static let tertiaryText = Color.white.opacity(0.42)
        static let disabledText = Color.white.opacity(0.28)

        static let temporary = Color.orange
        static let permanent = accent
        static let prompt = Color.purple
        static let success = Color.mint
        static let warning = Color.orange
        static let error = Color.red
        static let information = Color.cyan
    }

    enum Spacing {
        static let hairline: CGFloat = 1
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let panel: CGFloat = 24
        static let pill: CGFloat = 999
    }

    enum Icon {
        static let tiny: CGFloat = 16
        static let small: CGFloat = 24
        static let section: CGFloat = 28
        static let medium: CGFloat = 36
        static let large: CGFloat = 48
        static let hero: CGFloat = 64
    }

    enum Typography {
        static let display = Font.system(size: 17, weight: .bold, design: .rounded)
        static let heading = Font.system(size: 14, weight: .bold, design: .rounded)
        static let body = Font.system(size: 12, weight: .medium)
        static let bodyStrong = Font.system(size: 12, weight: .semibold)
        static let caption = Font.system(size: 10, weight: .medium)
        static let metadata = Font.system(size: 9, weight: .medium, design: .rounded)
        static let button = Font.system(size: 10, weight: .semibold, design: .rounded)
        static let count = Font.system(size: 11, weight: .bold, design: .rounded)
    }

    enum Motion {
        static let fast: Double = 0.16
        static let standard: Double = 0.20
        static let emphasized: Double = 0.28

        static let standardAnimation = Animation.easeOut(duration: standard)
        static let emphasizedAnimation = Animation.spring(
            response: 0.38,
            dampingFraction: 0.84,
            blendDuration: 0.04
        )
    }
}
