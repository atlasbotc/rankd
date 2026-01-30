import SwiftUI

struct UsernameEditorView: View {
    @Binding var username: String
    @State private var draft: String = ""
    @State private var validationMessage: String = ""
    @State private var isValid: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("@")
                        .font(RankdTypography.bodyLarge)
                        .foregroundStyle(RankdColors.textTertiary)
                    TextField("username", text: $draft)
                        .font(RankdTypography.bodyLarge)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: draft) { _, newValue in
                            validate(newValue)
                        }
                }
            } header: {
                Text("Choose a unique handle for your profile.")
            } footer: {
                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .foregroundStyle(isValid ? RankdColors.success : RankdColors.error)
                        .font(RankdTypography.caption)
                }
            }
            
            Section {
                Text("3–20 characters. Letters, numbers, and underscores only.")
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textTertiary)
            }
        }
        .navigationTitle("Username")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    username = draft
                    dismiss()
                }
                .disabled(!isValid)
                .font(RankdTypography.labelLarge)
                .foregroundStyle(isValid ? RankdColors.brand : RankdColors.textQuaternary)
            }
        }
        .onAppear {
            draft = username
            if !draft.isEmpty {
                validate(draft)
            }
        }
    }
    
    private func validate(_ value: String) {
        if value.isEmpty {
            validationMessage = ""
            isValid = false
            return
        }
        
        if value.count < 3 {
            validationMessage = "Too short — minimum 3 characters"
            isValid = false
            return
        }
        
        if value.count > 20 {
            validationMessage = "Too long — maximum 20 characters"
            isValid = false
            return
        }
        
        if !UserProfile.isValidUsername(value) {
            validationMessage = "Only letters, numbers, and underscores allowed"
            isValid = false
            return
        }
        
        validationMessage = "Looks good!"
        isValid = true
    }
}

#Preview {
    NavigationStack {
        UsernameEditorView(username: .constant(""))
    }
}
