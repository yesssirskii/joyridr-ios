import SwiftUI

/// Grey pill text field from the login/sign-up designs.
struct PillTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    @State private var isRevealed = false

    var body: some View {
        HStack {
            Group {
                if isSecure && !isRevealed {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .foregroundStyle(Theme.textPrimary)

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
        }
        .padding(.horizontal, 22)
        .frame(height: Theme.fieldHeight)
        .background(Theme.field, in: Capsule())
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(Theme.textSecondary)
    }
}

/// Red error text shown above a form's main button.
struct FormError: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.accentRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = "secret"
    VStack(spacing: 16) {
        PillTextField(placeholder: "Email", text: $email)
        PillTextField(placeholder: "Password", text: $password, isSecure: true)
        FormError(message: "Wrong email or password.")
    }
    .padding()
    .background(.black)
}
