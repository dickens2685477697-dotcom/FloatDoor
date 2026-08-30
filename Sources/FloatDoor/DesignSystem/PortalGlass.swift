import SwiftUI

/// A compact glass treatment shared by cards, controls, and icon plates.
struct PortalGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let emphasized: Bool
    let strokeColor: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fill = emphasized ? PortalTokens.Palette.glassElevated : PortalTokens.Palette.glass
        let stroke = strokeColor ?? (emphasized ? PortalTokens.Palette.glassStrokeStrong : PortalTokens.Palette.glassStroke)

        return content
            .background {
                if reduceTransparency {
                    shape.fill(PortalTokens.Palette.canvas)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(emphasized ? 0.085 : 0.045),
                            Color.white.opacity(0.012),
                            Color.black.opacity(0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                shape.fill(fill)
            }
            .overlay {
                shape.strokeBorder(stroke, lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(emphasized ? 0.28 : 0.20),
                radius: emphasized ? 16 : 10,
                y: emphasized ? 7 : 4
            )
    }
}

extension View {
    /// Applies the dark translucent surface used by the glass icon reference.
    func portalGlass(
        cornerRadius: CGFloat = PortalTokens.Radius.medium,
        emphasized: Bool = false,
        strokeColor: Color? = nil
    ) -> some View {
        modifier(
            PortalGlassModifier(
                cornerRadius: cornerRadius,
                emphasized: emphasized,
                strokeColor: strokeColor
            )
        )
    }

    /// The circular counterpart used for compact icon actions.
    func portalGlassCircle(
        emphasized: Bool = false,
        strokeColor: Color? = nil
    ) -> some View {
        let fill = emphasized ? PortalTokens.Palette.glassElevated : PortalTokens.Palette.glass
        let stroke = strokeColor ?? (emphasized ? PortalTokens.Palette.glassStrokeStrong : PortalTokens.Palette.glassStroke)

        return self
            .background {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(fill)
            }
            .overlay {
                Circle().strokeBorder(stroke, lineWidth: 1)
            }
    }
}
