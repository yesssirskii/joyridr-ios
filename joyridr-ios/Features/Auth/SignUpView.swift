import SwiftUI

struct SignUpView: View {
    let role: UserRole
    let onLogIn: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreedToTerms = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case firstName, lastName, username, email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AuthHeader(showsTagline: false)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a new account")
                        .font(.headline)
                    Text("as a \(role.title)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)

                VStack(alignment: .leading, spacing: 8) {
                    // One box for every field, split by lines, like the login screen.
                    FieldGroup {
                        // The backend needs first and last name separately (it shows "Ivan K." to others).
                        HStack(spacing: 0) {
                            FormTextField(placeholder: "First name", text: $firstName)
                                .textContentType(.givenName)
                                .focused($focusedField, equals: .firstName)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .lastName }
                            FieldDivider(.vertical)
                            FormTextField(placeholder: "Last name", text: $lastName)
                                .textContentType(.familyName)
                                .focused($focusedField, equals: .lastName)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .username }
                        }

                        FieldDivider()

                        FormTextField(placeholder: "Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }

                        FieldDivider()

                        FormTextField(placeholder: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }

                        FieldDivider()

                        FormTextField(placeholder: "Password", text: $password, isSecure: true)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(signUp)
                    }

                    // The rules sit under the box now; each turns red while its field breaks it.
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Username — \(Username.rules)")
                            .foregroundStyle(username.isEmpty || Username.isValid(Username.normalize(username)) ? Theme.textSecondary : Theme.accentRed)
                        Text("Password — at least 8 characters.")
                            .foregroundStyle(password.isEmpty || password.count >= 8 ? Theme.textSecondary : Theme.accentRed)
                    }
                    .font(.caption)
                    .padding(.leading, 22)
                }

                FormError(message: errorMessage)
                    .padding(.horizontal, 12)

                VStack(spacing: 10) {
                    // Apple wants users to agree to the terms (no tolerance for abusive content) before they
                    // can chat or post reviews, so this is a box to tick, not just a line of text.
                    termsAgreement
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)

                    Button("Sign Up", action: signUp)
                        .buttonStyle(.primary(isLoading: isLoading))
                        .disabled(isLoading)
                }
                .padding(.top, 6)

                // Part of the form rather than pinned to the bottom, where it covered the buttons above it.
                footer
                    .padding(.top, 4)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 16)
            .animation(.default, value: errorMessage)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AuthBackground() }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The tick box toggles on its own; the text holds the links, so tapping them opens the page instead.
    private var termsAgreement: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                agreedToTerms.toggle()
                if agreedToTerms, errorMessage == Self.termsError { errorMessage = nil }
            } label: {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(agreedToTerms ? Theme.accentRed : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("I agree to the Terms of Use and Privacy Policy")
            .accessibilityValue(agreedToTerms ? "Agreed" : "Not agreed")

            Text(Self.termsText)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let termsError = "Please agree to the Terms of Use and Privacy Policy."

    /// Built from Markdown so the two names become links. (Putting the URLs straight into `Text("…")`
    /// doesn't work: SwiftUI reads the Markdown before it fills in the values.)
    private static let termsText: AttributedString = {
        let markdown = "I agree to the [Terms of Use](\(AppConfig.termsURL.absoluteString)) and "
            + "[Privacy Policy](\(AppConfig.privacyURL.absoluteString)), including no tolerance for abusive content."
        guard var text = try? AttributedString(markdown: markdown) else {
            return AttributedString("I agree to the Terms of Use and Privacy Policy, including no tolerance for abusive content.")
        }
        // Underlined and white, so the links stand out from the grey text around them.
        for run in text.runs where run.link != nil {
            text[run.range].underlineStyle = .single
            text[run.range].foregroundColor = .white
        }
        return text
    }()

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
        let cleanUsername = Username.normalize(username)

        if first.isEmpty || last.isEmpty {
            errorMessage = "Enter your first and last name."
        } else if !Username.isValid(cleanUsername) {
            errorMessage = "Usernames are \(Username.rules)"
        } else if !trimmedEmail.contains("@") {
            errorMessage = "Enter a valid email address."
        } else if password.count < 8 {
            errorMessage = "Your password needs at least 8 characters."
        } else if !agreedToTerms {
            errorMessage = Self.termsError
        } else {
            focusedField = nil
            errorMessage = nil
            isLoading = true
            Task {
                defer { isLoading = false }
                do {
                    try await session.register(RegisterRequest(
                        email: trimmedEmail, username: cleanUsername, password: password, firstName: first, lastName: last,
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
