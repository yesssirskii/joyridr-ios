import Observation
import SwiftUI

/// "Forgot password?": enter your email, get a 6-digit code, then enter the code and a new password.
/// A successful reset logs you straight in, so RootView switches to the home screen by itself.
struct ForgotPasswordView: View {
    @Environment(SessionStore.self) private var session
    @State private var model: ForgotPasswordModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, code, password }

    init(email: String) {
        _model = State(initialValue: ForgotPasswordModel(email: email))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AuthHeader(showsTagline: false)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                switch model.step {
                case .email: emailStep
                case .code: codeStep
                }

                FormError(message: model.errorMessage)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 16)
            .animation(.default, value: model.errorMessage)
            .animation(.snappy, value: model.step)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AuthBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = model.email.isEmpty ? .email : nil }
    }

    // MARK: Step 1

    private var emailStep: some View {
        VStack(spacing: 18) {
            heading(t("auth.forgot.title"), t("auth.forgot.subtitle"))

            FieldGroup {
                FormTextField(placeholder: t("auth.email"), text: $model.email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.send)
                    .onSubmit(sendCode)
            }

            Button(t("auth.forgot.send_code"), action: sendCode)
                .buttonStyle(.primary(isLoading: model.isLoading))
                .disabled(model.isLoading)
                .padding(.top, 6)
        }
    }

    // MARK: Step 2

    private var codeStep: some View {
        VStack(spacing: 18) {
            heading(t("auth.forgot.check_title"), t("auth.forgot.check_subtitle", ["email": model.email]))

            VStack(alignment: .leading, spacing: 8) {
                FieldGroup {
                    FormTextField(placeholder: t("auth.forgot.code_placeholder"), text: $model.code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .code)
                        .onChange(of: model.code) { _, new in
                            let digits = String(new.filter(\.isNumber).prefix(6))
                            if digits != new { model.code = digits }
                            if digits.count == 6 && focusedField == .code { focusedField = .password }
                        }

                    FieldDivider()

                    FormTextField(placeholder: t("auth.forgot.new_password"), text: $model.newPassword, isSecure: true)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(reset)
                }

                Text(t("auth.password_rule"))
                    .font(.caption)
                    .foregroundStyle(model.newPassword.isEmpty || model.newPassword.count >= 8 ? Theme.textSecondary : Theme.accentRed)
                    .padding(.leading, 22)
            }

            Button(t("auth.forgot.reset"), action: reset)
                .buttonStyle(.primary(isLoading: model.isLoading))
                .disabled(model.isLoading)
                .padding(.top, 6)

            VStack(spacing: 10) {
                // Ticks every second so the countdown on "Resend code" stays current.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let wait = model.secondsUntilResend(at: context.date)
                    Button(wait > 0 ? t("auth.forgot.resend_in", ["seconds": wait]) : t("auth.forgot.resend")) {
                        Task { await model.resend() }
                    }
                    .underline(wait == 0)
                    .foregroundStyle(wait > 0 ? Theme.textSecondary : .white)
                    .disabled(wait > 0 || model.isLoading)
                }
                Button(t("auth.forgot.different_email")) {
                    model.changeEmail()
                    focusedField = .email
                }
                .foregroundStyle(Theme.textSecondary)
            }
            .font(.subheadline)
        }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func sendCode() {
        Task {
            if await model.sendCode() { focusedField = .code }
        }
    }

    private func reset() {
        focusedField = nil
        Task { await model.reset(using: session) }
    }
}

@Observable
final class ForgotPasswordModel {
    enum Step { case email, code }

    /// The backend sends at most one code a minute.
    static let resendDelay: TimeInterval = 60

    var email: String
    var code = ""
    var newPassword = ""
    private(set) var step: Step = .email
    private(set) var isLoading = false
    private(set) var lastSentAt: Date?
    var errorMessage: String?

    private let auth: AuthService

    init(email: String, auth: AuthService = AuthService()) {
        self.email = email
        self.auth = auth
    }

    func secondsUntilResend(at date: Date) -> Int {
        guard let lastSentAt else { return 0 }
        return max(0, Int((Self.resendDelay - date.timeIntervalSince(lastSentAt)).rounded(.up)))
    }

    /// Returns true once the code is on its way, so the view can focus the code field.
    func sendCode() async -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@") else {
            errorMessage = t("auth.forgot.error_email")
            return false
        }
        email = trimmed
        guard await send() else { return false }
        step = .code
        return true
    }

    func resend() async {
        code = ""
        if await send() { errorMessage = nil }
    }

    func changeEmail() {
        code = ""
        newPassword = ""
        errorMessage = nil
        step = .email
    }

    func reset(using session: SessionStore) async {
        guard code.count == 6 else {
            errorMessage = t("auth.forgot.error_code")
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = t("auth.forgot.error_password")
            return
        }
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await session.resetPassword(ResetPasswordRequest(email: email, code: code, newPassword: newPassword))
        } catch {
            errorMessage = error.localizedDescription
            // A code that can't work any more: clear it, so the next step is obviously "Resend code".
            if let code = (error as? APIError)?.code, code == "code_expired" || code == "too_many_attempts" {
                self.code = ""
            }
        }
    }

    private func send() async -> Bool {
        guard !isLoading else { return false }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.forgotPassword(email: email)
            lastSentAt = .now
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView(email: "rider@joyridr.dev")
    }
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}
