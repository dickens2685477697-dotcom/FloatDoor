import SwiftUI

struct NoticeBanner: View {
    let notice: PortalNotice
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: PortalTokens.Spacing.small) {
            PortalIcon(glyph: glyph, size: PortalTokens.Icon.small, tint: tint, showsPlate: false)

            Text(notice.text)
                .font(PortalTokens.Typography.caption)
                .lineLimit(2)

            Spacer(minLength: PortalTokens.Spacing.small)

            PortalIconButton(
                glyph: .close,
                size: PortalTokens.Icon.tiny,
                tint: tint,
                label: "关闭通知",
                action: dismiss
            )
        }
        .foregroundStyle(tint)
        .padding(.horizontal, PortalTokens.Spacing.medium)
        .padding(.vertical, PortalTokens.Spacing.small)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch notice.style {
        case .success: return PortalTokens.Palette.success
        case .error: return PortalTokens.Palette.error
        case .information: return PortalTokens.Palette.information
        }
    }

    private var glyph: PortalGlyph {
        switch notice.style {
        case .success: return .success
        case .error: return .error
        case .information: return .information
        }
    }
}
