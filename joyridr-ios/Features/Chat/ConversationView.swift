import SwiftUI

/// A chat with one rider or driver: message bubbles, a day header when the date changes, and the input bar.
struct ConversationView: View {
    @State private var model: ConversationModel
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @FocusState private var inputFocused: Bool

    init(conversation: Conversation) {
        _model = State(initialValue: ConversationModel(conversation: conversation))
    }

    init(otherUser: ChatParticipant) {
        _model = State(initialValue: ConversationModel(otherUser: otherUser))
    }

    var body: some View {
        content
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        RemoteImage(path: model.otherUser.avatarUrl, placeholder: "person.fill")
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 0) {
                            Text(model.otherUser.displayName)
                                .font(.headline)
                            Text(model.otherUser.isDriver ? "Driver" : "Rider")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .task {
                await model.load()
                await model.pollWhileVisible()
            }
            // Jump to the newest message whenever one arrives or is sent.
            .onChange(of: model.messages.last?.id) { scrollToBottom() }
            .onChange(of: model.pending.count) { scrollToBottom() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't open the chat", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded:
            messageList
        }
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if model.hasEarlier {
                    Button {
                        Task { await model.loadEarlier() }
                    } label: {
                        if model.isLoadingEarlier {
                            ProgressView()
                        } else {
                            Text("Load earlier messages")
                        }
                    }
                    .buttonStyle(ChipStyle(isSelected: false))
                    .padding(.vertical, 8)
                }

                if model.messages.isEmpty && model.pending.isEmpty {
                    emptyHint
                }

                ForEach(Array(model.messages.enumerated()), id: \.element.id) { index, message in
                    if index == 0 || !Calendar.current.isDate(message.createdAt, inSameDayAs: model.messages[index - 1].createdAt) {
                        DayHeader(date: message.createdAt)
                    }
                    MessageBubble(text: message.body, isMine: message.isMine, time: message.createdAt)
                        .id(message.id)
                }

                ForEach(model.pending) { message in
                    MessageBubble(text: message.body, isMine: true, time: nil,
                                  status: message.failed ? .failed : .sending)
                        .onTapGesture {
                            if message.failed { Task { await model.retry(message) } }
                        }
                        .contextMenu {
                            if message.failed {
                                Button("Try again", systemImage: "arrow.clockwise") { Task { await model.retry(message) } }
                                Button("Delete", systemImage: "trash", role: .destructive) { model.discard(message) }
                            }
                        }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.wave.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.accentRed)
            Text("Start the conversation")
                .font(.headline)
            Text(model.otherUser.isDriver
                 ? "Ask \(model.otherUser.firstName) about the car, the route or where to meet."
                 : "Say hi to \(model.otherUser.firstName) and sort out the details of the ride.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("", text: $model.draft,
                      prompt: Text("Message \(model.otherUser.firstName)").foregroundStyle(Theme.textSecondary),
                      axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 22))
                .onChange(of: model.draft) { _, new in
                    if new.count > ConversationModel.maxLength {
                        model.draft = String(new.prefix(ConversationModel.maxLength))
                    }
                }

            Button {
                Task { await model.send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(model.canSend ? Theme.brandRed : Theme.card, in: Circle())
            }
            .disabled(!model.canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .animation(.snappy, value: model.canSend)
    }

    private func scrollToBottom() {
        withAnimation(.snappy) { scrollPosition.scrollTo(edge: .bottom) }
    }
}

/// One chat bubble. Mine: red, on the right. Theirs: grey, on the left.
private struct MessageBubble: View {
    enum Status { case sent, sending, failed }

    let text: String
    let isMine: Bool
    let time: Date?
    var status: Status = .sent

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 56) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(isMine ? Theme.brandRed : Theme.card,
                                in: UnevenRoundedRectangle(
                                    topLeadingRadius: 18, bottomLeadingRadius: isMine ? 18 : 6,
                                    bottomTrailingRadius: isMine ? 6 : 18, topTrailingRadius: 18))
                    .opacity(status == .sending ? 0.6 : 1)
                footer
            }
            if !isMine { Spacer(minLength: 56) }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var footer: some View {
        switch status {
        case .sent:
            if let time {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        case .sending:
            Text("Sending…")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        case .failed:
            Label("Not sent. Tap to retry", systemImage: "exclamationmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.accentRed)
        }
    }
}

/// "Today", "Yesterday" or a date, between messages from different days.
private struct DayHeader: View {
    let date: Date

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.black.opacity(0.35), in: Capsule())
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    private var title: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// A conversation in its own sheet, opened from a "Message" button (not from the inbox).
struct ConversationSheet: View {
    let otherUser: ChatParticipant
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ConversationView(otherUser: otherUser)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
        }
    }
}
