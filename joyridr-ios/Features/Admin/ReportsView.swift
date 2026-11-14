import SwiftUI

/// Admin-only "Reports" tab: what users reported, oldest first. Apple expects reports to be handled within 24 hours.
struct ReportsView: View {
    @State private var model = ReportsModel()
    @State private var selected: Report?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader()

                    SectionTitle(title: t("tabs.reports"), subtitle: model.summary)

                    GlowCard {
                        list
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .background {
                ZStack(alignment: .top) {
                    Theme.background
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15)
                }
                .ignoresSafeArea()
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .animation(.snappy, value: model.reports)
            .sheet(item: $selected) { report in
                ReportDetailView(report: report, model: model)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var list: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            ContentUnavailableView {
                Label(t("admin.reports.load_failed"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(t("common.try_again")) { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.reports.isEmpty:
            ContentUnavailableView(t("admin.caught_up"), systemImage: "flag",
                                   description: Text(t("admin.reports.empty_message")))
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.reports) { report in
                    Button {
                        selected = report
                    } label: {
                        ReportRow(report: report)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ReportRow: View {
    let report: Report

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: report.reportedUser.avatarUrl, placeholder: "person.fill")
                .frame(width: 52, height: 52)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(report.reportedUser.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(report.kind.title) · \(report.reason.title)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text(report.createdAt.formatted(.relative(presentation: .named).locale(Localizer.shared.locale)))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            if report.openReportsAboutUser > 1 {
                CountBadge(count: report.openReportsAboutUser)
                    .accessibilityLabel(t("admin.reports.about_person", count: report.openReportsAboutUser))
            }
            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// One report with what was said, who reported it, and the three actions.
struct ReportDetailView: View {
    let report: Report
    let model: ReportsModel

    @Environment(\.dismiss) private var dismiss
    @State private var confirmRemove = false
    @State private var showBan = false
    @State private var banReason = ""

    private var isBusy: Bool { model.busyID == report.id }
    private var person: ReportUser { report.reportedUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    BookingSection(t("moderation.report")) {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledValue(label: t("admin.reports.what"), value: report.kind.title)
                            LabeledValue(label: t("schedule.reason"), value: report.reason.title)
                            if let details = report.details {
                                LabeledValue(label: t("admin.reports.details"), value: details)
                            }
                            LabeledValue(label: t("admin.reports.reported"), value: report.createdAt.localized(date: .abbreviated, time: .shortened))
                            LabeledValue(label: t("admin.reports.by"), value: "\(report.reporter.displayName) (@\(report.reporter.username))")
                        }
                    }

                    if let snapshot = report.contentSnapshot {
                        BookingSection(report.kind == .message ? t("admin.reports.message") : t("moderation.kind.review")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(snapshot)
                                if !report.contentExists {
                                    Text(t("admin.reports.already_removed"))
                                        .font(.footnote)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }

                    BookingSection(t("admin.reports.person")) {
                        HStack(spacing: 14) {
                            RemoteImage(path: person.avatarUrl, placeholder: "person.fill")
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.displayName)
                                    .font(.headline)
                                Text("@\(person.username) · \(person.role.title)")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                Text(person.isBanned ? t("admin.reports.banned")
                                     : person.openReportsText(report.openReportsAboutUser))
                                    .font(.footnote)
                                    .foregroundStyle(person.isBanned ? Theme.accentRed : Theme.textSecondary)
                            }
                        }
                    }

                    FormError(message: model.errorMessage)

                    VStack(spacing: 12) {
                        if report.contentExists {
                            Button(report.kind == .message ? t("admin.reports.remove_message") : t("admin.reports.remove_review")) { confirmRemove = true }
                                .buttonStyle(.primary(isLoading: isBusy))
                        }
                        if !person.isBanned && !person.isDeleted && person.role != .admin {
                            Button(t("admin.reports.ban_name", ["name": person.displayName])) {
                                banReason = ""
                                showBan = true
                            }
                            .buttonStyle(report.contentExists ? AnyButtonStyle(.secondary) : AnyButtonStyle(.primary(isLoading: isBusy)))
                        }
                        Button(t("admin.reports.dismiss")) {
                            Task { if await model.dismiss(report) { dismiss() } }
                        }
                        .buttonStyle(.secondary)
                    }
                    .disabled(isBusy)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.vertical, 12)
            }
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(t("moderation.report")).displayTitle(18)
                }
            }
            .alert(report.kind == .message ? t("admin.reports.remove_message_title") : t("admin.reports.remove_review_title"), isPresented: $confirmRemove) {
                Button(t("common.cancel"), role: .cancel) {}
                Button(t("common.remove"), role: .destructive) {
                    Task { if await model.removeContent(report) { dismiss() } }
                }
            } message: {
                Text(report.kind == .review
                     ? t("admin.reports.remove_review_message")
                     : t("admin.reports.remove_message_message"))
            }
            .alert(t("admin.reports.ban_question", ["name": person.displayName]), isPresented: $showBan) {
                TextField(t("admin.reports.ban_reason"), text: $banReason)
                Button(t("common.cancel"), role: .cancel) {}
                Button(t("admin.reports.ban"), role: .destructive) {
                    Task { if await model.ban(report, reason: banReason) { dismiss() } }
                }
            } message: {
                Text(t("admin.reports.ban_message"))
            }
            .animation(.snappy, value: model.errorMessage)
        }
        .tint(.white)
    }
}

private extension ReportUser {
    func openReportsText(_ count: Int) -> String {
        t("admin.reports.open", count: count)
    }
}

/// Lets one button switch between two button styles.
private struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
