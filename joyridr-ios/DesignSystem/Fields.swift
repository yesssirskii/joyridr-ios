import SwiftUI

/// A text field with its show/hide button for passwords, but no background: `PillTextField` gives it
/// a grey pill, and `FieldGroup` stacks several in one box. Its whole row is tappable, not just the
/// line of text in the middle.
struct FormTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Group {
                if isSecure && !isRevealed {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .focused($isFocused)
            .foregroundStyle(Theme.textPrimary)

            if isSecure {
                Button {
                    // Showing or hiding swaps SecureField for TextField, which would drop the keyboard.
                    let wasFocused = isFocused
                    isRevealed.toggle()
                    if wasFocused { isFocused = true }
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
        }
        .padding(.horizontal, 22)
        .frame(height: Theme.fieldHeight)
        // Taps above and below the line of text land on this background and focus the field. The tap
        // gesture sits on the background, not around the field, so taps on the text itself go straight
        // to the field without waiting for SwiftUI to rule out a tap gesture first.
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
        }
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(Theme.textSecondary)
    }
}

/// Grey pill text field from the login/sign-up designs.
struct PillTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        FormTextField(placeholder: placeholder, text: $text, isSecure: isSecure)
            .background(Theme.field, in: Capsule())
    }
}

/// Several fields in one liquid glass box, divided by thin lines, like email and password on the login
/// screen. Put a `FieldDivider()` between the fields.
struct FieldGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        // Plain glass. The shape is passed because the default, a capsule, would round a box this tall
        // into a pill.
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.fieldHeight / 2))
    }
}

/// The line between two fields in a `FieldGroup`, indented to line up with the text.
/// `FieldDivider(.vertical)` splits two fields side by side, like first and last name.
struct FieldDivider: View {
    var axis: Axis = .horizontal

    init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    var body: some View {
        if axis == .horizontal {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
                .padding(.horizontal, 22)
        } else {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: Theme.fieldHeight - 24)
        }
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
        FieldGroup {
            FormTextField(placeholder: "Email", text: $email)
            FieldDivider()
            FormTextField(placeholder: "Password", text: $password, isSecure: true)
        }
        PillTextField(placeholder: "Username", text: $email)
        FormError(message: "Wrong email or password.")
    }
    .padding()
    .background(.black)
}
