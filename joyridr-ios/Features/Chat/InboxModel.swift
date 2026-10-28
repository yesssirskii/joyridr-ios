import Foundation
import Observation

@Observable
final class InboxModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    private(set) var conversations: [Conversation] = []
    private(set) var state: LoadState = .loading

    private let chat: ChatService

    init(chat: ChatService = ChatService()) {
        self.chat = chat
    }

    func load() async {
        do {
            conversations = try await chat.conversations()
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            if conversations.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    /// Refreshes every few seconds while the inbox is on screen, so new messages and unread counts show up.
    func pollWhileVisible() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            await load()
        }
    }
}
