import Foundation
import Observation

/// The admin's report queue. Dismissing, removing the content or banning takes reports off the list.
@Observable
final class ReportsModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    private(set) var reports: [Report] = []
    private(set) var state: LoadState = .loading
    /// The report being acted on, so its buttons show a spinner.
    private(set) var busyID: Report.ID?
    var errorMessage: String?

    private let admin: AdminService

    init(admin: AdminService = AdminService()) {
        self.admin = admin
    }

    var summary: String {
        switch reports.count {
        case 0: "Nothing reported"
        case 1: "1 open report"
        default: "\(reports.count) open reports"
        }
    }

    func load() async {
        do {
            reports = try await admin.openReports()
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            if reports.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    /// Each returns true when it worked, so the detail sheet knows to close.
    func dismiss(_ report: Report) async -> Bool {
        await act(on: report) { try await $0.dismiss(report.id) }
    }

    func removeContent(_ report: Report) async -> Bool {
        await act(on: report) { try await $0.removeContent(of: report.id) }
    }

    func ban(_ report: Report, reason: String) async -> Bool {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return await act(on: report) { try await $0.ban(report.reportedUser.id, reason: trimmed.isEmpty ? nil : trimmed) }
    }

    private func act(on report: Report, _ call: (AdminService) async throws -> Void) async -> Bool {
        guard busyID == nil else { return false }
        busyID = report.id
        errorMessage = nil
        defer { busyID = nil }
        do {
            try await call(admin)
            // Removing content or banning can close other reports too, so reload rather than guess.
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
