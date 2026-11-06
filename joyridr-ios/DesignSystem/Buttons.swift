import SwiftUI

/// Big red full-width liquid glass button ("Log in", "Sign Up"). Shows a spinner instead of the label while loading.
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    @Environment(\.isEnabled) private var isEnabled

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
        .contentShape(Capsule())
        // Red liquid glass. `.interactive()` makes it react to the finger the way system buttons do:
        // it swells and lights up under the touch, then springs back.
        .glassEffect(.regular.tint(Theme.brandRed).interactive(), in: Capsule())
        // Faded while disabled, so it's clear there's nothing to tap. Not while loading: the spinner says enough.
        .opacity(isEnabled || isLoading ? 1 : 0.4)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
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

#Preview {
    VStack(spacing: 16) {
        Button("Log in") {}.buttonStyle(.primary)
        Button("Log in") {}.buttonStyle(.primary(isLoading: true))
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

/// The ✕ in the top-left corner that closes a sheet. White, so it stands out better than the app's red tint.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button("Close", systemImage: "xmark", action: action)
            .tint(.white)
    }
}
