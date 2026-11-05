import PhotosUI
import SwiftUI

/// Account sheet opened from the profile button: who you are (tap the picture to change it), your username, and log out.
struct ProfileView: View {
    /// Closes the sheet and logs out once it's gone (see `HomeHeader`).
    let onLogOut: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    
    @State private var model = ProfileModel()
    @State private var confirmLogout = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var editingUsername = false
    @State private var newUsername = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let me = session.me {
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $avatarItem, matching: .images) {
                                avatar(me.user)
                            }
                            .disabled(model.isUploadingAvatar)
                            .accessibilityLabel("Change profile picture")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(me.user.fullName)
                                    .font(.title3.weight(.semibold))
                                Text("@\(me.user.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                Text(me.user.role.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.accentRed)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))

                        FormError(message: model.errorMessage)

                        BookingSection("Account") {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    LabeledValue(label: "Username", value: "@\(me.user.username)")
                                    Spacer()
                                    Button("Change") {
                                        newUsername = me.user.username
                                        editingUsername = true
                                    }
                                    .buttonStyle(ChipStyle(isSelected: false))
                                    .disabled(model.isSavingUsername)
                                }
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

                            BaseLocationSection(driver: driver)
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
                    CloseButton { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("Profile").displayTitle(18)
                }
            }
            // An alert rather than a confirmation dialog: centred, larger, and it dims the screen behind it.
            .alert("Log out of JOYRIDR?", isPresented: $confirmLogout) {
                Button("Cancel", role: .cancel) {}
                Button("Log out", role: .destructive, action: onLogOut)
            } message: {
                Text("You'll need your email and password to log back in.")
            }
            .alert("Change username", isPresented: $editingUsername) {
                TextField("Username", text: $newUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    guard let user = session.me?.user else { return }
                    Task { if await model.changeUsername(to: newUsername, for: user) { await session.reloadMe() } }
                }
            } message: {
                Text(Username.rules)
            }
            .onChange(of: avatarItem) {
                guard let item = avatarItem else { return }
                Task {
                    if await model.uploadAvatar(item) { await session.reloadMe() }
                    avatarItem = nil
                }
            }
            .animation(.snappy, value: model.errorMessage)
        }
        // Alerts take their button colour from the tint: white makes Cancel neutral, and Log out stays red
        // because it's destructive. (The app's tint is red, which made both buttons red.)
        .tint(.white)
    }

    /// The profile picture with a small camera badge, so it's clear it can be tapped.
    private func avatar(_ user: User) -> some View {
        RemoteImage(path: user.avatarUrl, placeholder: "person.fill")
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay {
                if model.isUploadingAvatar {
                    Circle().fill(.black.opacity(0.5))
                    ProgressView()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Theme.brandRed, in: Circle())
                    .offset(x: 2, y: 2)
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
