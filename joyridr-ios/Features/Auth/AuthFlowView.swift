import SwiftUI

/// Login → Choose role → Sign up, in one navigation stack.
struct AuthFlowView: View {
    enum Route: Hashable {
        case chooseRole
        case signUp(UserRole)
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(onSignUp: { path.append(.chooseRole) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .chooseRole:
                        ChooseRoleView { role in path.append(.signUp(role)) }
                    case let .signUp(role):
                        SignUpView(role: role, onLogIn: { path.removeAll() })
                    }
                }
        }
        .tint(.white)
    }
}

/// "JOYRIDR / LET'S GO FOR A RIDE!" at the top of the auth screens.
struct AuthHeader: View {
    /// Sign-up hides "Let's go for a ride!" to leave room for its longer form.
    var showsTagline = true

    var body: some View {
        VStack(spacing: 6) {
            Text("JOYRIDR")
                .font(Theme.display(54))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if showsTagline {
                Text("Let's go for a ride!")
                    .displayTitle(17)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Stripes background shared by the auth screens.
struct AuthBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RacingStripes(count: 4, lineWidth: 16, spacing: 42, startX: -0.3)
        }
        .ignoresSafeArea()
    }
}
