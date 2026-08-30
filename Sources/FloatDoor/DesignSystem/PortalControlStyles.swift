import SwiftUI

/// Standard count chip used in the portal header and section switcher.
struct PortalCountChip: View {
    let count: Int
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: PortalTokens.Spacing.xSmall) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
                .shadow(color: tint.opacity(0.55), radius: 3)

            Text("\(count) \(label)")
                .font(PortalTokens.Typography.button)
                .foregroundStyle(PortalTokens.Palette.primaryText.opacity(0.72))
        }
        .padding(.horizontal, PortalTokens.Spacing.small)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(PortalTokens.Palette.glass))
        )
        .overlay(Capsule().strokeBorder(PortalTokens.Palette.glassStroke, lineWidth: 1))
    }
}

/// Text-only glass button style for secondary actions.
struct PortalTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PortalTokens.Typography.button)
            .foregroundStyle(
                PortalTokens.Palette.primaryText.opacity(configuration.isPressed ? 0.56 : 0.78)
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(Capsule())
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().fill(
                            configuration.isPressed
                                ? PortalTokens.Palette.glassPressed
                                : PortalTokens.Palette.glassElevated
                        )
                    )
            )
            .overlay(Capsule().strokeBorder(PortalTokens.Palette.glassStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(PortalTokens.Motion.standardAnimation, value: configuration.isPressed)
    }
}

/// A semantic status badge for success, information, warning, and error
/// states. It is intentionally small so it can be used in list rows.
struct PortalStatusBadge: View {
    let glyph: PortalGlyph
    let text: String
    var tint: Color?

    init(glyph: PortalGlyph, text: String, tint: Color? = nil) {
        self.glyph = glyph
        self.text = text
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: PortalTokens.Spacing.xSmall) {
            PortalIcon(glyph: glyph, size: PortalTokens.Icon.tiny, tint: tint, showsPlate: false)
            Text(text)
                .font(PortalTokens.Typography.caption)
        }
        .foregroundStyle(tint ?? glyph.defaultTint)
        .padding(.horizontal, PortalTokens.Spacing.small)
        .padding(.vertical, 5)
        .background((tint ?? glyph.defaultTint).opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder((tint ?? glyph.defaultTint).opacity(0.23), lineWidth: 1))
    }
}
