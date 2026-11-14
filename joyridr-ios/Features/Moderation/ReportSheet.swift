import SwiftUI

/// "Report" for a person, a chat message or a review: pick a reason, optionally add details and block them too.
/// Reports go to the JOYRIDR team, who can remove the content or ban the account.
struct ReportSheet: View {
    let target: ReportTarget
    /// Called after the person was blocked as part of the report, so the screen behind can update.
    var onBlocked: (UUID) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var details = ""
    @State private var alsoBlock = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sent = false

    private let moderation = ModerationService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(heading)
                        .font(.headline)
                    if let quote {
                        Text(quote)
                            .font(.subheadline)
                            .lineLimit(4)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                    }

                    BookingSection(t("moderation.why")) {
                        VStack(spacing: 0) {
                            ForEach(ReportReason.allCases) { option in
                                Button {
                                    reason = option
                                } label: {
                                    HStack {
                                        Text(option.title)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: reason == option ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(reason == option ? Theme.accentRed : Theme.textSecondary)
                                    }
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(reason == option ? .isSelected : [])
                                if option != ReportReason.allCases.last {
                                    Divider().overlay(Color.white.opacity(0.12))
                                }
                            }
                        }
                    }

                    BookingSection(t("moderation.anything_else")) {
                        TextField("", text: $details,
                                  prompt: Text(t("moderation.what_happened")).foregroundStyle(Theme.textSecondary),
                                  axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: details) { _, new in
                                if new.count > 1000 { details = String(new.prefix(1000)) }
                            }
                    }

                    if let person = target.person {
                        Toggle(t("moderation.also_block", ["name": person.name]), isOn: $alsoBlock)
                            .tint(Theme.brandRed)
                            .padding(.horizontal, 4)
                        Text(t("moderation.also_block_message"))
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.top, -14)
                    }

                    FormError(message: errorMessage)

                    Button(t("moderation.send_report"), action: send)
                        .buttonStyle(.primary(isLoading: isSending))
                        .disabled(reason == nil || isSending)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(t("moderation.report")).displayTitle(18)
                }
            }
            .alert(t("moderation.thanks"), isPresented: $sent) {
                Button(t("common.ok")) { dismiss() }
            } message: {
                Text(t("moderation.thanks_message"))
            }
            .animation(.snappy, value: errorMessage)
        }
        .tint(.white)
    }

    private var heading: String {
        switch target {
        case let .user(_, name): t("moderation.report_name", ["name": name])
        case let .message(_, _, name): t("moderation.report_message_from", ["name": name])
        case let .review(review): t("moderation.report_review_by", ["name": review.authorName])
        }
    }

    private var quote: String? {
        switch target {
        case .user: nil
        case let .message(message, _, _): message.body
        case let .review(review): review.comment.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    private func send() {
        guard let reason, !isSending else { return }
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        errorMessage = nil
        Task {
            defer { isSending = false }
            do {
                try await moderation.report(target.request(reason, trimmed.isEmpty ? nil : trimmed))
                if alsoBlock, let person = target.person {
                    try await moderation.block(person.id)
                    onBlocked(person.id)
                }
                sent = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ReportSheet(target: .user(id: UUID(), name: "Ivan K."))
        .preferredColorScheme(.dark)
}
