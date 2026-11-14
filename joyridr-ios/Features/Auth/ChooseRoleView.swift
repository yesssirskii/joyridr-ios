import SwiftUI

/// "CHOOSE YOUR DESTINY": pick JoyRider or JoyDriver before signing up.
struct ChooseRoleView: View {
    let onChoose: (UserRole) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(t("auth.role.title"))
                .displayTitle(22)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.bottom, 30)

            RoleOption(title: "JoyRider", caption: t("auth.role.rider_caption")) {
                onChoose(.joyRider)
            }

            Text(t("auth.role.or"))
                .displayTitle(16)

            RoleOption(title: "JoyDriver", caption: t("auth.role.driver_caption")) {
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
