import SwiftUI

struct LoginView: View {
    let onSignUp: () -> Void
    /// Opens the reset screen with the email typed so far.
    let onForgotPassword: (String) -> Void

    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var notice: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AuthHeader()
                    .padding(.top, 110)
                    .padding(.bottom, 44)

                Text(t("auth.login.heading"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)

                // One box for both, split by a line.
                FieldGroup {
                    FormTextField(placeholder: t("auth.email"), text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    FieldDivider()

                    FormTextField(placeholder: t("auth.password"), text: $password, isSecure: true)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(logIn)
                }

                Button(t("auth.login.forgot")) { onForgotPassword(email.trimmingCharacters(in: .whitespaces)) }
                    .font(.footnote)
                    .underline()
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 12)

                FormError(message: errorMessage)
                    .padding(.horizontal, 12)

                Button(t("auth.login.button"), action: logIn)
                    .buttonStyle(.primary(isLoading: isLoading))
                    .disabled(isLoading)
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
        .task {
            // E.g. "account deleted". Shown once the profile sheet has finished closing: an alert
            // presented while it's still on screen gets dropped.
            guard let message = session.signedOutNotice else { return }
            session.signedOutNotice = nil
            try? await Task.sleep(for: .milliseconds(600))
            notice = message
        }
        .alert(t("auth.login.account_deleted"), isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(t("common.ok"), role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(t("auth.login.no_account"))
                .foregroundStyle(Theme.textSecondary)
            Button(t("auth.login.sign_up_link"), action: onSignUp)
                .underline()
        }
        .font(.subheadline)
        .padding(.bottom, 8)
    }

    private func logIn() {
        guard !isLoading else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = t("auth.login.error_missing")
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
        LoginView(onSignUp: {}, onForgotPassword: { _ in })
    }
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}
