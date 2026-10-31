import SwiftUI

/// "TIME OFF": block out whole days or part of a day.
struct TimeOffEditorView: View {
    let onSave: (Date, Date, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var allDay = true
    @State private var start = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
    @State private var end = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
    @State private var reason = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var keyboardVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    BookingSection("When") {
                        VStack(spacing: 0) {
                            Toggle("All day", isOn: $allDay)
                                .tint(Theme.accentRed)
                                .padding(.vertical, 8)
                            Divider().overlay(.white.opacity(0.1))
                            DatePicker(allDay ? "First day" : "Starts", selection: $start, in: Date.now...,
                                       displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                                .padding(.vertical, 8)
                            Divider().overlay(.white.opacity(0.1))
                            DatePicker(allDay ? "Last day" : "Ends", selection: $end, in: start...,
                                       displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                                .padding(.vertical, 8)
                        }
                    }

                    BookingSection("Reason") {
                        TextField("", text: $reason, prompt: Text("Holiday, car in service… (optional)").foregroundStyle(Theme.textSecondary))
                            .submitLabel(.done)
                    }

                    Label(summary, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if !keyboardVisible { bottomBar }
            }
            .trackKeyboard($keyboardVisible)
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Time off").displayTitle(18)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .onChange(of: start) { _, newStart in
                if end < newStart { end = newStart }
            }
            .animation(.snappy, value: allDay)
            .animation(.snappy, value: errorMessage)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            FormError(message: errorMessage)
            Button("Add time off") { Task { await save() } }
                .buttonStyle(.primary(isLoading: isSaving))
                .disabled(isSaving)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// The exact period sent to the backend. All-day ends at midnight after the last day.
    private var period: (start: Date, end: Date) {
        let calendar = Calendar.current
        guard allDay else { return (start, end) }
        let first = calendar.startOfDay(for: start)
        let afterLast = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        return (first, afterLast)
    }

    private var summary: String {
        let days = Calendar.current.dateComponents([.day], from: period.start, to: period.end).day ?? 0
        return allDay
            ? "You'll be unavailable for \(days) day\(days == 1 ? "" : "s"). If you already have rides then, cancel or decline them first."
            : "If you already have rides in this period, cancel or decline them first."
    }

    private func save() async {
        let (from, to) = period
        guard to > from else {
            errorMessage = "Time off has to end after it starts."
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(from, to, reason)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
