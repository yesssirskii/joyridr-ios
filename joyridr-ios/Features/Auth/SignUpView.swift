import SwiftUI

struct SignUpView: View {
    let role: UserRole
    let onLogIn: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case firstName, lastName, email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AuthHeader()
                    .padding(.top, 60)
                    .padding(.bottom, 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a new account")
                        .font(.headline)
                    Text("as a \(role.title)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)

                // The backend needs first and last name separately (it shows "Ivan K." to others).
                HStack(spacing: 10) {
                    PillTextField(placeholder: "First name", text: $firstName)
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .firstName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastName }
                    PillTextField(placeholder: "Last name", text: $lastName)
                        .textContentType(.familyName)
                        .focused($focusedField, equals: .lastName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }

                PillTextField(placeholder: "Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                VStack(alignment: .leading, spacing: 6) {
                    PillTextField(placeholder: "Password", text: $password, isSecure: true)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signUp)
                    Text("At least 8 characters")
                        .font(.caption)
                        .foregroundStyle(password.isEmpty || password.count >= 8 ? Theme.textSecondary : Theme.accentRed)
                        .padding(.leading, 22)
                }

                FormError(message: errorMessage)
                    .padding(.horizontal, 12)

                Button("Sign Up", action: signUp)
                    .buttonStyle(.primary(isLoading: isLoading))
                    .disabled(isLoading)

                Text("or")
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 4)

                SocialSignInRow(verb: "Sign up")

                Text("By signing up you agree to the Terms of Service and Privacy Policy.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 20)
            .animation(.default, value: errorMessage)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            // Hidden while typing, otherwise it rides up with the keyboard and covers the form.
            if focusedField == nil {
                footer
            }
        }
        .background { AuthBackground() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundStyle(Theme.textSecondary)
            Button("Log in.", action: onLogIn)
                .underline()
        }
        .font(.subheadline)
        .padding(.bottom, 8)
    }

    private func signUp() {
        guard !isLoading else { return }
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        if first.isEmpty || last.isEmpty {
            errorMessage = "Enter your first and last name."
        } else if !trimmedEmail.contains("@") {
            errorMessage = "Enter a valid email address."
        } else if password.count < 8 {
            errorMessage = "Your password needs at least 8 characters."
        } else {
            focusedField = nil
            errorMessage = nil
            isLoading = true
            Task {
                defer { isLoading = false }
                do {
                    try await session.register(RegisterRequest(
                        email: trimmedEmail, password: password, firstName: first, lastName: last,
                        phoneNumber: nil, role: role))
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView(role: .joyDriver, onLogIn: {})
    }
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}
