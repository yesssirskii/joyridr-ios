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
                            .accessibilityLabel(t("profile.change_picture"))
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

                        BookingSection(t("profile.account")) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    LabeledValue(label: t("auth.username"), value: "@\(me.user.username)")
                                    Spacer()
                                    Button(t("profile.change")) {
                                        newUsername = me.user.username
                                        editingUsername = true
                                    }
                                    .buttonStyle(ChipStyle(isSelected: false))
                                    .disabled(model.isSavingUsername)
                                }
                                LabeledValue(label: t("auth.email"), value: me.user.email)
                                LabeledValue(label: t("profile.phone"), value: me.user.phoneNumber ?? t("profile.not_added"))
                                LabeledValue(label: t("profile.member_since"), value: me.user.createdAt.localized(.dateTime.month(.wide).year()))
                            }
                        }

                        if let driver = me.driverProfile {
                            BookingSection(t("booking.car_info.driver")) {
                                VStack(alignment: .leading, spacing: 14) {
                                    LabeledValue(label: t("profile.verification"), value: driver.isVerified ? t("profile.verified") + " ✓" : t("profile.not_verified"))
                                    LabeledValue(label: t("explore.sort.rating"), value: driver.ratingCount == 0 ? t("profile.no_reviews") : "★ \(driver.ratingAverage.formatted(.number.locale(Localizer.shared.locale).precision(.fractionLength(1)).locale(Localizer.shared.locale))) (\(driver.ratingCount))")
                                    LabeledValue(label: t("profile.completed_rides"), value: "\(driver.completedRides)")
                                }
                            }

                            BaseLocationSection(driver: driver)
                        }
                    }

                    BookingSection(t("profile.privacy_safety")) {
                        NavigationLink {
                            BlockedUsersView()
                        } label: {
                            HStack {
                                Label(t("moderation.blocked_title"), systemImage: "hand.raised")
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    BookingSection(t("profile.language")) {
                        // Switches the whole app at once; the choice is remembered (see Localizer).
                        Picker(t("profile.language"), selection: Binding(
                            get: { Localizer.shared.language },
                            set: { Localizer.shared.language = $0 })
                        ) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.nativeName).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    BookingSection(t("profile.legal")) {
                        VStack(alignment: .leading, spacing: 14) {
                            LegalLinkRow(title: t("profile.terms"), systemImage: "doc.text", url: AppConfig.termsURL)
                            LegalLinkRow(title: t("profile.privacy"), systemImage: "lock.shield", url: AppConfig.privacyURL)
                        }
                    }

                    Button(t("profile.log_out"), systemImage: "rectangle.portrait.and.arrow.right") { confirmLogout = true }
                        .buttonStyle(.secondary)

                    Button {
                        deletePassword = ""
                        confirmDelete = true
                    } label: {
                        if model.isDeletingAccount {
                            ProgressView()
                        } else {
                            Text(t("profile.delete_account"))
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
                    Text(t("profile.title")).displayTitle(18)
                }
            }
            // An alert rather than a confirmation dialog: centred, larger, and it dims the screen behind it.
            .alert(t("profile.log_out_title"), isPresented: $confirmLogout) {
                Button(t("common.cancel"), role: .cancel) {}
                Button(t("profile.log_out"), role: .destructive, action: onLogOut)
            } message: {
                Text(t("profile.log_out_message"))
            }
            .alert(t("profile.delete_title"), isPresented: $confirmDelete) {
                SecureField(t("auth.password"), text: $deletePassword)
                    .textContentType(.password)
                Button(t("common.cancel"), role: .cancel) {}
                Button(t("common.delete"), role: .destructive) {
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
                Text(t("profile.delete_message"))
            }
            .alert(t("profile.change_username"), isPresented: $editingUsername) {
                TextField(t("auth.username"), text: $newUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(t("common.cancel"), role: .cancel) {}
                Button(t("common.save")) {
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
