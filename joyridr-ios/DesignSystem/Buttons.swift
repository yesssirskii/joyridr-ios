import SwiftUI

/// Big red full-width button ("Log in", "Sign Up"). Shows a spinner instead of the label while loading.
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label.opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView().tint(.white)
            }
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: Theme.fieldHeight)
        .background(Theme.brandRed, in: Capsule())
        .opacity(configuration.isPressed ? 0.8 : 1)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(isLoading: Bool) -> PrimaryButtonStyle { PrimaryButtonStyle(isLoading: isLoading) }
}

/// Round icon button with a frosted background (profile, close, chat...).
struct CircleIconButton: View {
    let systemImage: String
    var size: CGFloat = 52
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Small number badge, e.g. unread messages.
struct CountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: 22, minHeight: 22)
                .background(Theme.accentRed, in: Capsule())
        }
    }
}

/// "Log in with Google/Apple" pill. Not wired to the backend yet.
struct SocialButton: View {
    enum Provider { case google, apple }

    let provider: Provider
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: provider == .apple ? "apple.logo" : "g.circle.fill")
                    .font(.title3)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(provider == .google ? .black : .white)
            .background(provider == .google ? Color.white : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: provider == .apple ? 1 : 0))
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Log in") {}.buttonStyle(.primary)
        Button("Log in") {}.buttonStyle(.primary(isLoading: true))
        HStack {
            SocialButton(provider: .google, title: "Log in with") {}
            SocialButton(provider: .apple, title: "Log in with") {}
        }
        HStack {
            CircleIconButton(systemImage: "person", accessibilityLabel: "Profile") {}
            CountBadge(count: 3)
        }
    }
    .padding()
    .background(.black)
}

/// Grey capsule button for secondary actions ("Decline").
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Theme.card, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
