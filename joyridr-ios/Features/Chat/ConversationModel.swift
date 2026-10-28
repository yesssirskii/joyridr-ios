import Foundation
import Observation

/// One open chat: loads messages, checks for new ones every few seconds, and sends.
@Observable
final class ConversationModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    /// A message the user typed that the server hasn't confirmed yet.
    struct PendingMessage: Identifiable, Equatable {
        let id = UUID()
        let body: String
        var failed = false
    }

    static let pageSize = 50
    static let maxLength = 2000

    let otherUser: ChatParticipant
    private(set) var conversationID: UUID?
    private(set) var messages: [ChatMessage] = []
    private(set) var pending: [PendingMessage] = []
    private(set) var state: LoadState = .loading
    /// The first page was full, so there may be older messages.
    private(set) var hasEarlier = false
    private(set) var isLoadingEarlier = false
    var draft = ""

    private let chat: ChatService

    /// Open an existing conversation (from the inbox).
    init(conversation: Conversation, chat: ChatService = ChatService()) {
        otherUser = conversation.otherUser
        conversationID = conversation.id
        self.chat = chat
    }

    /// Open (or create) the conversation with someone, e.g. "Message Ivan" on a ride.
    init(otherUser: ChatParticipant, chat: ChatService = ChatService()) {
        self.otherUser = otherUser
        self.chat = chat
    }

    var canSend: Bool {
        conversationID != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        do {
            let id: UUID
            if let conversationID {
                id = conversationID
            } else {
                id = try await chat.start(with: otherUser.id).id
                conversationID = id
            }
            let latest = try await chat.messages(in: id, limit: Self.pageSize)
            messages = latest
            hasEarlier = latest.count == Self.pageSize
            state = .loaded
            try? await chat.markRead(id)
        } catch {
            if Task.isCancelled { return }
            state = .failed(error.localizedDescription)
        }
    }

    /// Checks for new messages every 3 seconds until the screen goes away (the task is cancelled).
    func pollWhileVisible() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            await fetchNew()
        }
    }

    func loadEarlier() async {
        guard let conversationID, let oldest = messages.first, !isLoadingEarlier else { return }
        isLoadingEarlier = true
        defer { isLoadingEarlier = false }
        if let older = try? await chat.messages(in: conversationID, before: oldest.id, limit: Self.pageSize) {
            messages.insert(contentsOf: older, at: 0)
            hasEarlier = older.count == Self.pageSize
        }
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        draft = ""
        let message = PendingMessage(body: String(body.prefix(Self.maxLength)))
        pending.append(message)
        await deliver(message)
    }

    func retry(_ message: PendingMessage) async {
        guard let index = pending.firstIndex(where: { $0.id == message.id }) else { return }
        pending[index].failed = false
        await deliver(pending[index])
    }

    func discard(_ message: PendingMessage) {
        pending.removeAll { $0.id == message.id }
    }

    // MARK: Private

    private func deliver(_ message: PendingMessage) async {
        guard let conversationID else { return }
        do {
            let sent = try await chat.send(message.body, in: conversationID)
            pending.removeAll { $0.id == message.id }
            append([sent])
        } catch {
            if let index = pending.firstIndex(where: { $0.id == message.id }) {
                pending[index].failed = true
            }
        }
    }

    private func fetchNew() async {
        guard let conversationID, state == .loaded else { return }
        // Ask for messages after the newest one we have. Using the id (not the time) means nothing is
        // skipped or shown twice.
        guard let fresh = try? await chat.messages(in: conversationID, after: messages.last?.id, limit: Self.pageSize),
              !fresh.isEmpty else { return }
        append(fresh)
        if fresh.contains(where: { !$0.isMine }) {
            try? await chat.markRead(conversationID)
        }
    }

    /// Adds messages, skipping any we already have (a poll can race with a send).
    private func append(_ new: [ChatMessage]) {
        let known = Set(messages.map(\.id))
        messages.append(contentsOf: new.filter { !known.contains($0.id) })
    }
}
