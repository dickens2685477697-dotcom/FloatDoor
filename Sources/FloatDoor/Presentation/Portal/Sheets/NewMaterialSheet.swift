import OSLog
import SwiftUI

private enum NewMaterialKind: String, CaseIterable, Identifiable {
    case text
    case link

    var id: Self { self }

    var title: String {
        switch self {
        case .text: return "文本"
        case .link: return "链接"
        }
    }
}

struct NewMaterialSheet: View {
    private static let logger = Logger(subsystem: "FloatDoor", category: "NewMaterial")
    @ObservedObject var store: PortalStore
    let scope: StorageScope
    let onDismiss: () -> Void

    @State private var kind: NewMaterialKind = .text
    @State private var value = ""
    @FocusState private var isInputFocused: Bool

    init(
        store: PortalStore,
        scope: StorageScope = .permanent,
        onDismiss: @escaping () -> Void
    ) {
        self.store = store
        self.scope = scope
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("新建\(scope == .custom ? store.customAreaName : store.materialAreaName)")
                .font(PortalTokens.Typography.display)
                .foregroundStyle(PortalTokens.Palette.primaryText)

            Picker("类型", selection: $kind) {
                ForEach(NewMaterialKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if kind == .text {
                TextEditor(text: $value)
                    .font(.body)
                    .focused($isInputFocused)
                    .frame(height: 130)
                    .scrollContentBackground(.hidden)
                    .padding(PortalTokens.Spacing.small)
                    .background(PortalTokens.Palette.glass)
                    .overlay(
                        RoundedRectangle(cornerRadius: PortalTokens.Radius.small, style: .continuous)
                            .stroke(PortalTokens.Palette.glassStrokeStrong, lineWidth: 1)
                    )
            } else {
                TextField("https://example.com", text: $value)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .padding(PortalTokens.Spacing.small)
                    .portalGlass(cornerRadius: PortalTokens.Radius.small)
            }

            HStack {
                Spacer()
                Button("取消", action: onDismiss)
                    .buttonStyle(PortalTextButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(PortalTokens.Palette.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(PortalTokens.Palette.canvas)
        .preferredColorScheme(.dark)
        .tint(PortalTokens.Palette.accent)
        .task {
            await Task.yield()
            isInputFocused = true
        }
        .onChange(of: kind) {
            isInputFocused = false
            Task { @MainActor in
                await Task.yield()
                isInputFocused = true
            }
        }
    }

    private func save() {
        Self.logger.notice("Save requested for material kind \(kind.rawValue, privacy: .public)")
        switch kind {
        case .text:
            store.importText(value, into: scope)
        case .link:
            let normalized = value.contains("://") ? value : "https://\(value)"
            guard let url = URL(string: normalized), url.host != nil else {
                store.reportImportFailure("请输入有效链接。")
                return
            }
            store.importURL(url, into: scope)
        }
        onDismiss()
    }
}
