import SwiftUI

/// Account sheet opened from the profile button. For now: who you are and log out.
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let me = session.me {
                        HStack(spacing: 16) {
                            RemoteImage(path: me.user.avatarUrl, placeholder: "person.fill")
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(me.user.fullName)
                                    .font(.title3.weight(.semibold))
                                Text(me.user.role.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.accentRed)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))

                        BookingSection("Account") {
                            VStack(alignment: .leading, spacing: 14) {
                                LabeledValue(label: "Email", value: me.user.email)
                                LabeledValue(label: "Phone", value: me.user.phoneNumber ?? "Not added yet")
                                LabeledValue(label: "Member since", value: me.user.createdAt.formatted(.dateTime.month(.wide).year()))
                            }
                        }

                        if let driver = me.driverProfile {
                            BookingSection("Driver") {
                                VStack(alignment: .leading, spacing: 14) {
                                    LabeledValue(label: "Verification", value: driver.isVerified ? "Verified ✓" : "Not verified yet")
                                    LabeledValue(label: "Rating", value: driver.ratingCount == 0 ? "No reviews yet" : "★ \(driver.ratingAverage.formatted(.number.precision(.fractionLength(1)))) (\(driver.ratingCount))")
                                    LabeledValue(label: "Completed rides", value: "\(driver.completedRides)")
                                }
                            }
                        }
                    }

                    Button("Log out", systemImage: "rectangle.portrait.and.arrow.right") { confirmLogout = true }
                        .buttonStyle(.secondary)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("Profile").displayTitle(18)
                }
            }
            .confirmationDialog("Log out of JOYRIDR?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Log out", role: .destructive) {
                    Task { await session.logout() }
                }
            }
        }
    }
}

/// Grey label above a white value, like "Name / Dejan Bubalo" in the designs.
struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.body.weight(.semibold))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
