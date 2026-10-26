import SwiftUI

struct LoginView: View {
    let onSignUp: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AuthHeader()
                    .padding(.top, 110)
                    .padding(.bottom, 44)

                Text("Already a user? Log in")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)

                PillTextField(placeholder: "Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                PillTextField(placeholder: "Password", text: $password, isSecure: true)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(logIn)

                Button("Forgot password?") { showForgotPassword = true }
                    .font(.footnote)
                    .underline()
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)

                FormError(message: errorMessage)
                    .padding(.horizontal, 12)

                Button("Log in", action: logIn)
                    .buttonStyle(.primary(isLoading: isLoading))
                    .disabled(isLoading)

                Text("or")
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 4)

                SocialSignInRow(verb: "Log in")
            }
            .padding(.horizontal, Theme.horizontalPadding)
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
        .toolbar(.hidden, for: .navigationBar)
        .alert("Coming soon", isPresented: $showForgotPassword) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password reset isn't available yet.")
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(Theme.textSecondary)
            Button("Sign up.", action: onSignUp)
                .underline()
        }
        .font(.subheadline)
        .padding(.bottom, 8)
    }

    private func logIn() {
        guard !isLoading else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and password."
            return
        }

        focusedField = nil
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await session.login(email: trimmedEmail, password: password)
                // RootView switches to the home screen automatically once the session is signed in.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView(onSignUp: {})
    }
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}
