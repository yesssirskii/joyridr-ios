import SwiftUI

/// "CHOOSE YOUR DESTINY": pick JoyRider or JoyDriver before signing up.
struct ChooseRoleView: View {
    let onChoose: (UserRole) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Choose your destiny")
                .displayTitle(22)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.bottom, 30)

            RoleOption(title: "JoyRider", caption: "You'll book drivers to take you for a ride.") {
                onChoose(.joyRider)
            }

            Text("or")
                .displayTitle(16)

            RoleOption(title: "JoyDriver", caption: "JoyRiders choose you to take them for a ride.") {
                onChoose(.joyDriver)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.horizontalPadding)
        .background { AuthBackground() }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RoleOption: View {
    let title: String
    let caption: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(title, action: action)
                .buttonStyle(.primary)
            Text(caption)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    NavigationStack {
        ChooseRoleView { _ in }
    }
    .preferredColorScheme(.dark)
}
