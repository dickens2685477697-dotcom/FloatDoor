import SwiftUI

struct RenameItemSheet: View {
    @Binding var proposedName: String
    let originalName: String
    let title: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        proposedName: Binding<String>,
        originalName: String,
        title: String = "重命名素材",
        onSave: @escaping () -> Void
    ) {
        self._proposedName = proposedName
        self.originalName = originalName
        self.title = title
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(PortalTokens.Typography.display)
                .foregroundStyle(PortalTokens.Palette.primaryText)

            TextField("名称", text: $proposedName)
                .textFieldStyle(.plain)
                .padding(PortalTokens.Spacing.small)
                .portalGlass(cornerRadius: PortalTokens.Radius.small)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(PortalTextButtonStyle())
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(PortalTokens.Palette.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(PortalTokens.Palette.canvas)
        .preferredColorScheme(.dark)
        .tint(PortalTokens.Palette.accent)
    }

    private func save() {
        guard proposedName != originalName else {
            dismiss()
            return
        }
        onSave()
        dismiss()
    }
}
