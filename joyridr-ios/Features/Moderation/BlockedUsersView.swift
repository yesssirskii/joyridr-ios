import Observation
import SwiftUI

/// "Blocked people" in the profile: everyone you blocked, with Unblock.
struct BlockedUsersView: View {
    @State private var model = BlockedUsersModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch model.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                case let .failed(message):
                    ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(message))
                case .loaded where model.users.isEmpty:
                    ContentUnavailableView("Nobody blocked", systemImage: "hand.raised",
                                           description: Text("People you block can't message you or book with you, and you won't see their cars."))
                case .loaded:
                    FormError(message: model.errorMessage)
                    ForEach(model.users) { user in
                        HStack(spacing: 14) {
                            RemoteImage(path: user.avatarUrl, placeholder: "person.fill")
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text("Blocked \(user.blockedAt.formatted(.dateTime.day().month(.abbreviated).year()))")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Button("Unblock") { Task { await model.unblock(user) } }
                                .buttonStyle(ChipStyle(isSelected: false))
                                .disabled(model.busyID == user.id)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 12)
            .animation(.snappy, value: model.users)
        }
        .background { RedGlow().ignoresSafeArea() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Blocked people").displayTitle(18)
            }
        }
        .task { await model.load() }
    }
}

@Observable
final class BlockedUsersModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    private(set) var users: [BlockedUser] = []
    private(set) var state: LoadState = .loading
    private(set) var busyID: UUID?
    var errorMessage: String?

    private let moderation = ModerationService()

    func load() async {
        do {
            users = try await moderation.blockedUsers()
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            state = .failed(error.localizedDescription)
        }
    }

    func unblock(_ user: BlockedUser) async {
        busyID = user.id
        errorMessage = nil
        defer { busyID = nil }
        do {
            try await moderation.unblock(user.id)
            users.removeAll { $0.id == user.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
