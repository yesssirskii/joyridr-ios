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
    var body: some View {
        VStack(spacing: 6) {
            Text("JOYRIDR")
                .font(Theme.display(54))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Let's go for a ride!")
                .displayTitle(17)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
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

/// "Log in with Google/Apple" row. Shows a "coming soon" alert until the backend supports it.
struct SocialSignInRow: View {
    let verb: String
    @State private var showComingSoon = false

    var body: some View {
        HStack(spacing: 14) {
            SocialButton(provider: .google, title: "\(verb) with") { showComingSoon = true }
            SocialButton(provider: .apple, title: "\(verb) with") { showComingSoon = true }
        }
        .alert("Coming soon", isPresented: $showComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Google and Apple sign-in are on the way. Use your email for now.")
        }
    }
}
