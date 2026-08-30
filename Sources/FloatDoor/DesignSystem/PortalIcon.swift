import AppKit
import SwiftUI

/// Semantic icon names used by the portal. Business views depend on these
/// names rather than asset strings or platform-symbol identifiers.
enum PortalGlyph: String, CaseIterable, Sendable {
    case door
    case temporary
    case permanent
    case text
    case image
    case link
    case file
    case add
    case download
    case quote
    case clock
    case success
    case information
    case warning
    case error
    case close
    case collapse
    case more
    case tray
    case prompt
    case rename
    case delete

    var defaultTint: Color {
        switch self {
        case .door, .permanent, .download, .success:
            return PortalTokens.Palette.accent
        case .temporary, .clock:
            return PortalTokens.Palette.temporary
        case .text, .image, .link, .file, .quote, .prompt:
            return PortalTokens.Palette.icon
        case .add:
            return PortalTokens.Palette.accentBright
        case .information:
            return PortalTokens.Palette.information
        case .warning:
            return PortalTokens.Palette.warning
        case .error:
            return PortalTokens.Palette.error
        case .close, .collapse, .more, .tray, .rename:
            return PortalTokens.Palette.secondaryText
        case .delete:
            return PortalTokens.Palette.error
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .door: return "Float Door"
        case .temporary: return "一次性"
        case .permanent: return "长期素材"
        case .text: return "文本"
        case .image: return "图片"
        case .link: return "链接"
        case .file: return "文件"
        case .add: return "添加"
        case .download: return "导入"
        case .quote: return "引用"
        case .clock: return "时间"
        case .success: return "成功"
        case .information: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        case .close: return "关闭"
        case .collapse: return "收起"
        case .more: return "更多"
        case .tray: return "暂存区"
        case .prompt: return "Prompt"
        case .rename: return "重命名"
        case .delete: return "删除"
        }
    }
}

/// A reference-image tile for structural icons plus a compact vector fallback
/// for controls. `showsPlate: false` keeps small controls free of the 222px
/// glass tile background.
struct PortalIcon: View {
    let glyph: PortalGlyph
    var size: CGFloat = PortalTokens.Icon.medium
    var tint: Color?
    var showsPlate = true
    var accessibilityLabel: String?

    init(
        glyph: PortalGlyph,
        size: CGFloat = PortalTokens.Icon.medium,
        tint: Color? = nil,
        showsPlate: Bool = true,
        accessibilityLabel: String? = nil
    ) {
        self.glyph = glyph
        self.size = size
        self.tint = tint
        self.showsPlate = showsPlate
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        ZStack {
            if showsPlate {
                PortalReferenceTile(glyph: glyph, size: size)
            } else {
                PortalGlyphShape(glyph: glyph)
                    .stroke(
                        glyphGradient,
                        style: StrokeStyle(
                            lineWidth: max(size * 0.052, 1.35),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .padding(size * 0.18)
                    .shadow(color: (tint ?? glyph.defaultTint).opacity(0.22), radius: size * 0.10, y: size * 0.045)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel ?? glyph.accessibilityLabel)
    }

    private var glyphGradient: LinearGradient {
        let base = tint ?? glyph.defaultTint
        return LinearGradient(
            colors: [
                tint == nil ? PortalTokens.Palette.iconHighlight : base.opacity(0.98),
                base.opacity(0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Exact tile crop from the supplied reference image. The image is bundled
/// for runtime use so the Logo and structural icon plates retain the original
/// bevel, glow, and glass texture rather than a redraw.
private struct PortalReferenceTile: View {
    let glyph: PortalGlyph
    let size: CGFloat

    private let sourceSize: CGFloat = 1_254
    private let tileSize: CGFloat = 222

    var body: some View {
        Group {
            if let image = PortalReferenceImage.master {
                GeometryReader { proxy in
                    let scale = proxy.size.width / tileSize
                    let origin = cropOrigin

                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: sourceSize * scale, height: sourceSize * scale)
                        .offset(x: -origin.x * scale, y: -origin.y * scale)
                }
            } else {
                // Keep the UI legible if a packaged resource is missing.
                PortalGlyphShape(glyph: glyph)
                    .stroke(
                        PortalTokens.Palette.icon,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: max(size * 0.14, 4),
                style: .continuous
            )
        )
    }

    private var cropOrigin: CGPoint {
        let column: CGFloat
        let row: CGFloat

        switch glyph {
        case .door: column = 98; row = 125
        case .tray: column = 378; row = 125
        case .permanent: column = 658; row = 125
        case .collapse: column = 938; row = 125
        case .text: column = 98; row = 397
        case .image: column = 378; row = 397
        case .link: column = 658; row = 397
        case .file: column = 938; row = 397
        case .add: column = 98; row = 669
        case .quote, .prompt: column = 378; row = 669
        case .download: column = 658; row = 669
        case .clock, .temporary: column = 938; row = 669
        case .success: column = 98; row = 941
        case .information: column = 378; row = 941
        case .warning, .error: column = 658; row = 941
        case .more, .close, .rename, .delete: column = 938; row = 941
        }

        return CGPoint(x: column, y: row)
    }
}

private final class PortalResourceBundleMarker: NSObject {}

private enum PortalReferenceImage {
    /// Xcode and SwiftPM can expose processed resources through different
    /// bundle objects depending on how the executable is launched. Missing
    /// artwork must never abort the app: `PortalReferenceTile` has a vector
    /// fallback for that case.
    static let master: NSImage? = {
        let bundles = [
            Bundle.module,
            Bundle.main,
            Bundle(for: PortalResourceBundleMarker.self)
        ]

        for bundle in bundles {
            let urls = [
                bundle.url(forResource: "glass-icon-master", withExtension: "png"),
                bundle.url(forResource: "glass-icon-master", withExtension: "png", subdirectory: "Icons")
            ].compactMap { $0 }

            for url in urls {
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }

        return nil
    }()
}

/// Code-native vector paths mirrored by `Design/Icons/glass-icons.svg`.
/// Keeping the geometry here avoids runtime SVG parsing while removing visible
/// SF Symbol dependencies from the portal UI.
private struct PortalGlyphShape: Shape {
    let glyph: PortalGlyph

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch glyph {
        case .door:
            path.move(to: p(5, 20)); path.addLine(to: p(5, 5)); path.addLine(to: p(14, 3)); path.addLine(to: p(14, 21)); path.closeSubpath()
            path.move(to: p(14, 5)); path.addLine(to: p(19, 5)); path.addLine(to: p(19, 19)); path.addLine(to: p(14, 19))
            path.addEllipse(in: r(11.3, 11.3, 1.4, 1.4))
        case .temporary:
            path.addEllipse(in: r(4, 4, 16, 16)); path.move(to: p(12, 7)); path.addLine(to: p(12, 12)); path.addLine(to: p(15, 14))
            path.move(to: p(6, 5)); path.addLine(to: p(4, 5)); path.addLine(to: p(4, 7))
        case .permanent:
            path.addRect(r(5, 8, 14, 11)); path.addRect(r(4, 5, 16, 3)); path.move(to: p(10, 12)); path.addLine(to: p(14, 12))
        case .text:
            path.move(to: p(5, 5)); path.addLine(to: p(19, 5)); path.move(to: p(12, 5)); path.addLine(to: p(12, 19)); path.move(to: p(9, 19)); path.addLine(to: p(15, 19))
        case .image:
            path.addRoundedRect(in: r(4, 5, 16, 14), cornerSize: CGSize(width: 2, height: 2)); path.addEllipse(in: r(7.5, 8.5, 3, 3))
            path.move(to: p(6, 17)); path.addLine(to: p(10, 13)); path.addLine(to: p(13, 16)); path.addLine(to: p(15, 14)); path.addLine(to: p(18, 17))
        case .link:
            path.addRoundedRect(in: r(2.5, 9, 10, 6), cornerSize: CGSize(width: 3, height: 3)); path.addRoundedRect(in: r(11.5, 9, 10, 6), cornerSize: CGSize(width: 3, height: 3)); path.move(to: p(8.5, 12)); path.addLine(to: p(15.5, 12))
        case .file:
            path.move(to: p(6, 3)); path.addLine(to: p(14, 3)); path.addLine(to: p(18, 7)); path.addLine(to: p(18, 21)); path.addLine(to: p(6, 21)); path.closeSubpath()
            path.move(to: p(14, 3)); path.addLine(to: p(14, 8)); path.addLine(to: p(19, 8))
        case .add:
            path.move(to: p(12, 5)); path.addLine(to: p(12, 19)); path.move(to: p(5, 12)); path.addLine(to: p(19, 12))
        case .download:
            path.move(to: p(12, 4)); path.addLine(to: p(12, 15)); path.move(to: p(7, 10)); path.addLine(to: p(12, 15)); path.addLine(to: p(17, 10)); path.move(to: p(5, 16)); path.addLine(to: p(5, 19)); path.addLine(to: p(19, 19)); path.addLine(to: p(19, 16))
        case .quote, .prompt:
            path.addRoundedRect(in: r(4, 7, 6, 6), cornerSize: CGSize(width: 2, height: 2)); path.move(to: p(10, 11)); path.addQuadCurve(to: p(6, 19), control: p(10, 17))
            path.addRoundedRect(in: r(14, 7, 6, 6), cornerSize: CGSize(width: 2, height: 2)); path.move(to: p(20, 11)); path.addQuadCurve(to: p(16, 19), control: p(20, 17))
        case .clock:
            path.addEllipse(in: r(4, 4, 16, 16)); path.move(to: p(12, 7)); path.addLine(to: p(12, 12)); path.addLine(to: p(15, 14))
        case .success:
            path.addEllipse(in: r(4, 4, 16, 16)); path.move(to: p(8, 12)); path.addLine(to: p(11, 15)); path.addLine(to: p(17, 9))
        case .information:
            path.addEllipse(in: r(4, 4, 16, 16)); path.addEllipse(in: r(11.5, 7, 1, 1)); path.move(to: p(12, 11)); path.addLine(to: p(12, 17))
        case .warning, .error:
            path.move(to: p(12, 4)); path.addLine(to: p(21, 20)); path.addLine(to: p(3, 20)); path.closeSubpath(); path.move(to: p(12, 9)); path.addLine(to: p(12, 14)); path.addEllipse(in: r(11.5, 17, 1, 1))
        case .close:
            path.move(to: p(7, 7)); path.addLine(to: p(17, 17)); path.move(to: p(17, 7)); path.addLine(to: p(7, 17))
        case .collapse:
            path.move(to: p(5, 14)); path.addLine(to: p(12, 7)); path.addLine(to: p(19, 14))
        case .more:
            path.addEllipse(in: r(4.5, 10.5, 3, 3)); path.addEllipse(in: r(10.5, 10.5, 3, 3)); path.addEllipse(in: r(16.5, 10.5, 3, 3))
        case .tray:
            path.move(to: p(4, 11)); path.addLine(to: p(8, 11)); path.addLine(to: p(10, 14)); path.addLine(to: p(14, 14)); path.addLine(to: p(16, 11)); path.addLine(to: p(20, 11)); path.addLine(to: p(20, 18)); path.addLine(to: p(4, 18)); path.closeSubpath()
            path.move(to: p(6, 11)); path.addLine(to: p(8, 6)); path.addLine(to: p(16, 6)); path.addLine(to: p(18, 11))
        case .rename:
            path.move(to: p(5, 18)); path.addLine(to: p(8, 17)); path.addLine(to: p(18, 7)); path.addLine(to: p(15, 4)); path.addLine(to: p(5, 14)); path.closeSubpath()
            path.move(to: p(13.5, 5.5)); path.addLine(to: p(16.5, 8.5))
        case .delete:
            path.addRoundedRect(in: r(6, 7, 12, 13), cornerSize: CGSize(width: 2, height: 2)); path.move(to: p(4, 7)); path.addLine(to: p(20, 7)); path.move(to: p(9, 7)); path.addLine(to: p(10, 4)); path.addLine(to: p(14, 4)); path.addLine(to: p(15, 7)); path.move(to: p(10, 11)); path.addLine(to: p(10, 16)); path.move(to: p(14, 11)); path.addLine(to: p(14, 16))
        }

        let scale = min(rect.width, rect.height) / 24
        let transform = CGAffineTransform(translationX: rect.midX - 12 * scale, y: rect.midY - 12 * scale).scaledBy(x: scale, y: scale)
        return path.applying(transform)
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    private func r(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

/// A compact round button that uses the same glass plate treatment as
/// `PortalIcon`. Use this for close, collapse, overflow, and promote actions.
struct PortalIconButton: View {
    let glyph: PortalGlyph
    let action: () -> Void
    var size: CGFloat = PortalTokens.Icon.small
    var tint: Color?
    var helpText: String?
    var label: String?

    init(
        glyph: PortalGlyph,
        size: CGFloat = PortalTokens.Icon.small,
        tint: Color? = nil,
        helpText: String? = nil,
        label: String? = nil,
        action: @escaping () -> Void
    ) {
        self.glyph = glyph
        self.size = size
        self.tint = tint
        self.helpText = helpText
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            PortalIcon(glyph: glyph, size: size, tint: tint, showsPlate: false)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(PortalIconButtonStyle(tint: tint ?? glyph.defaultTint))
        .help(helpText ?? label ?? glyph.accessibilityLabel)
        .accessibilityLabel(label ?? glyph.accessibilityLabel)
    }
}

struct PortalIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(configuration.isPressed ? PortalTokens.Palette.glassPressed : PortalTokens.Palette.glass))
            )
            .overlay {
                Circle().strokeBorder(
                    tint.opacity(configuration.isPressed ? 0.42 : 0.22),
                    lineWidth: 1
                )
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(PortalTokens.Motion.standardAnimation, value: configuration.isPressed)
    }
}
