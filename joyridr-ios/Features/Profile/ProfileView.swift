import PhotosUI
import SwiftUI

/// Account sheet opened from the profile button: who you are (tap the picture to change it), your username,
/// blocked people, log out and delete account.
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
    @State private var confirmDelete = false
    @State private var deletePassword = ""

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

                    BookingSection("Privacy & safety") {
                        NavigationLink {
                            BlockedUsersView()
                        } label: {
                            HStack {
                                Label("Blocked people", systemImage: "hand.raised")
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    BookingSection("Legal") {
                        VStack(alignment: .leading, spacing: 14) {
                            LegalLinkRow(title: "Terms of Use", systemImage: "doc.text", url: AppConfig.termsURL)
                            LegalLinkRow(title: "Privacy Policy", systemImage: "lock.shield", url: AppConfig.privacyURL)
                        }
                    }

                    Button("Log out", systemImage: "rectangle.portrait.and.arrow.right") { confirmLogout = true }
                        .buttonStyle(.secondary)

                    Button {
                        deletePassword = ""
                        confirmDelete = true
                    } label: {
                        if model.isDeletingAccount {
                            ProgressView()
                        } else {
                            Text("Delete account")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentRed)
                    .frame(maxWidth: .infinity)
                    .disabled(model.isDeletingAccount)
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
            .alert("Delete your account?", isPresented: $confirmDelete) {
                SecureField("Password", text: $deletePassword)
                    .textContentType(.password)
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    let password = deletePassword
                    deletePassword = ""
                    Task {
                        if await model.deleteAccount(password: password) {
                            dismiss()
                            session.accountDeleted()
                        }
                    }
                }
            } message: {
                Text("This can't be undone. Your upcoming rides are cancelled under the usual rules, and your profile, photos, cars, messages and review texts are deleted. Records of past rides and payments are kept without your details, as accounting rules require.\n\nEnter your password to confirm.")
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

/// A row that opens one of the legal pages in Safari, styled like the "Blocked people" row.
private struct LegalLinkRow: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(Theme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
