import SwiftUI

/// "Messages": every conversation, most recent first. Opened from the chat button on the home screens.
struct InboxView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model = InboxModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionTitle(title: "Messages", subtitle: subtitle)
                    GlowCard {
                        content
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background {
                ZStack(alignment: .top) {
                    Theme.background
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15, length: 0.35)
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(for: Conversation.self) { conversation in
                ConversationView(conversation: conversation)
            }
            .refreshable { await model.load() }
            // Runs whenever the inbox is shown again (e.g. coming back from a conversation), and keeps it fresh.
            .task {
                await model.load()
                await model.pollWhileVisible()
            }
        }
    }

    private var subtitle: String {
        session.me?.user.role == .joyDriver ? "Chats with your JoyRiders" : "Chats with drivers"
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load messages", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.conversations.isEmpty:
            ContentUnavailableView(
                "No messages yet",
                systemImage: "bubble.left.and.bubble.right",
                description: Text(session.me?.user.role == .joyDriver
                    ? "When a JoyRider messages you, it shows up here."
                    : "Message a driver from one of your rides and the chat shows up here."))
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.conversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRow(conversation: conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// One conversation in the inbox, styled like the car rows.
private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: conversation.otherUser.avatarUrl, placeholder: "person.fill")
                .frame(width: 56, height: 56)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.otherUser.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(conversation.otherUser.isDriver ? "Driver" : "Rider")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Text(timeText)
                        .font(.caption)
                        .foregroundStyle(conversation.unreadCount > 0 ? Theme.accentRed : Theme.textSecondary)
                }
                HStack(alignment: .top) {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(conversation.unreadCount > 0 ? .white : Theme.textSecondary)
                        .fontWeight(conversation.unreadCount > 0 ? .semibold : .regular)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    CountBadge(count: conversation.unreadCount)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var preview: String {
        guard let message = conversation.lastMessage else { return "Say hi 👋" }
        return message.isMine ? "You: \(message.body)" : message.body
    }

    private var timeText: String {
        let date = conversation.lastActivity
        if Calendar.current.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
