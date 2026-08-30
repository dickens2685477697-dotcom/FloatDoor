import SwiftUI

/// Empty-state artwork assembled from the portal's existing semantic icons.
/// Keeping it code-native preserves sharp edges at every display scale and
/// lets the drop-target state share the same accent colour as the rest of UI.
struct PortalDropCompositionIcon: View {
    var isDropTarget = false

    private let artworkSize = CGSize(width: 138, height: 104)

    var body: some View {
        ZStack(alignment: .topLeading) {
            iconCard(.text, size: 43)
                .rotationEffect(.degrees(-13))
                .offset(x: 16, y: 2)

            iconCard(.image, size: 45)
                .offset(x: 48, y: -4)

            iconCard(.link, size: 43)
                .rotationEffect(.degrees(13))
                .offset(x: 82, y: 3)

            tray
                .frame(width: 124, height: 57)
                .offset(x: 7, y: 38)

            downloadBadge
                .offset(x: 52, y: 69)
        }
        .frame(width: artworkSize.width, height: artworkSize.height)
        .shadow(
            color: (isDropTarget ? PortalTokens.Palette.accent : Color.black).opacity(0.28),
            radius: isDropTarget ? 15 : 10,
            y: 6
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("支持拖入文字、图片、链接和文件")
    }

    private func iconCard(_ glyph: PortalGlyph, size: CGFloat) -> some View {
        PortalIcon(
            glyph: glyph,
            size: size,
            tint: PortalTokens.Palette.icon
        )
        .accessibilityHidden(true)
        .shadow(color: Color.black.opacity(0.34), radius: 5, y: 3)
    }

    private var tray: some View {
        PortalDropTrayShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDropTarget ? 0.19 : 0.14),
                        Color(red: 0.28, green: 0.33, blue: 0.42).opacity(0.44),
                        Color.black.opacity(0.38)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                PortalDropTrayShape()
                    .strokeBorder(
                        isDropTarget
                            ? PortalTokens.Palette.accent.opacity(0.72)
                            : Color.white.opacity(0.18),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 100, height: 1)
                    .padding(.top, 1)
            }
    }

    private var downloadBadge: some View {
        PortalIcon(
            glyph: .download,
            size: 15,
            tint: .white,
            showsPlate: false
        )
        .accessibilityHidden(true)
        .frame(width: 34, height: 34)
        .background {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            PortalTokens.Palette.accentBright,
                            PortalTokens.Palette.accentDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            Circle().strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: PortalTokens.Palette.accent.opacity(0.42), radius: 7, y: 3)
    }
}

private struct PortalDropTrayShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let lipY = bounds.minY + bounds.height * 0.16
        let cornerRadius = min(bounds.width * 0.1, bounds.height * 0.24)

        var path = Path()
        path.move(to: CGPoint(x: bounds.minX, y: lipY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: lipY))
        path.addLine(to: CGPoint(x: bounds.maxX - 7, y: bounds.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: bounds.maxX - 7 - cornerRadius, y: bounds.maxY),
            control: CGPoint(x: bounds.maxX - 7, y: bounds.maxY)
        )
        path.addLine(to: CGPoint(x: bounds.minX + 7 + cornerRadius, y: bounds.maxY))
        path.addQuadCurve(
            to: CGPoint(x: bounds.minX + 7, y: bounds.maxY - cornerRadius),
            control: CGPoint(x: bounds.minX + 7, y: bounds.maxY)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> PortalDropTrayShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
