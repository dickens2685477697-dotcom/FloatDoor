import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(store: PortalStore) {
        let viewController = NSHostingController(rootView: SettingsView(store: store))
        let window = NSWindow(contentViewController: viewController)
        window.title = "Float Door 设置"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 430, height: 320))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct SettingsView: View {
    @ObservedObject var store: PortalStore

    var body: some View {
        Form {
            Section("一次性区域") {
                Picker(
                    "默认过期时间",
                    selection: Binding(
                        get: { store.temporaryRetention },
                        set: { store.setTemporaryRetention($0) }
                    )
                ) {
                    ForEach(TemporaryRetention.allCases) { retention in
                        Text(retention.displayName).tag(retention)
                    }
                }

                Button("立即清理过期内容") {
                    store.purgeExpired()
                }
            }

            Section("存储") {
                LabeledContent(
                    "当前占用空间",
                    value: ByteCountFormatter.string(fromByteCount: store.storageUsage, countStyle: .file)
                )

                Button("打开存储目录") {
                    NSWorkspace.shared.open(store.storageRootURL)
                }
            }

            Section("阶段范围") {
                Text("一次性、长期素材和自定义区域均已支持本地保存。浏览器扩展和 ChatGPT 投递将在后续阶段实现。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .tint(PortalTokens.Palette.accent)
        .preferredColorScheme(.dark)
        .background(PortalTokens.Palette.canvas)
    }
}
