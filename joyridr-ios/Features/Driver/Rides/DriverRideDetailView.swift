import SwiftUI

/// Everything about one booking from the driver's side: who the rider is, when and where,
/// the money, and the next step (confirm, start, complete, rate).
/// Opens from a request card or an upcoming ride with a zoom transition.
struct DriverRideDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: DriverRideModel
    @State private var showChat = false
    @State private var showDecline = false
    @State private var showCancel = false
    @State private var confirmComplete = false
    /// Typed into the decline or cancel alert; the rider sees it.
    @State private var reason = ""
    @FocusState private var commentFocused: Bool

    init(ride: Ride) {
        _model = State(initialValue: DriverRideModel(ride: ride))
    }

    private var ride: Ride { model.ride }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RiderCard(ride: ride) { showChat = true }

                    DriverRideBanner(ride: ride, riderFirstName: model.riderFirstName,
                                     startAvailableAt: model.startAvailableAt)

                    BookingSection("Ride details") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledValue(label: "Car", value: ride.car.name)
                            LabeledValue(label: "When", value: whenText)
                            LabeledValue(label: "Duration", value: durationLabel(ride.durationMinutes))
                            meetingPoint
                            if let phone = ride.rider.phoneNumber {
                                HStack {
                                    LabeledValue(label: "\(model.riderFirstName)'s phone", value: phone)
                                    Spacer()
                                    smallAction("Call", systemImage: "phone.fill") {
                                        if let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") { openURL(url) }
                                    }
                                }
                            }
                            if let note = ride.riderNote, !note.isEmpty {
                                LabeledValue(label: "\(model.riderFirstName)'s note", value: "“\(note)”")
                            }
                        }
                    }

                    BookingSection("Payment") {
                        HStack(alignment: .firstTextBaseline) {
                            LabeledValue(label: paymentText, value: ride.price.price(ride.currency))
                            Spacer()
                        }
                    }

                    if ride.canReview || model.reviewSent {
                        BookingSection("Rate \(model.riderFirstName)") {
                            reviewForm
                        }
                    }

                    // Only shown here when there's no bottom bar to show it in.
                    if !hasBottomBar {
                        FormError(message: model.errorMessage)
                    }

                    if ride.status == .confirmed {
                        Button(role: .destructive) {
                            reason = ""
                            showCancel = true
                        } label: {
                            if model.busyAction == .cancel {
                                ProgressView().tint(.white)
                            } else {
                                Text("Cancel ride").foregroundStyle(Theme.accentRed)
                            }
                        }
                        .buttonStyle(.secondary)
                        .disabled(model.busyAction != nil)
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if hasBottomBar {
                    bottomBar
                }
            }
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(ride.status == .requested ? "Ride request" : "Ride").displayTitle(18)
                }
                // The keyboard covers "Send review", so give it a way out.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { commentFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .refreshable { await model.refresh() }
            .animation(.snappy, value: ride)
            .animation(.snappy, value: model.reviewSent)
            .animation(.snappy, value: model.errorMessage)
        }
        .task { await model.refresh() }
        .alert("Decline this ride?", isPresented: $showDecline) {
            TextField("Reason (optional)", text: $reason)
            Button("Decline ride", role: .destructive) {
                Task { await model.decline(reason: reason) }
            }
            Button("Keep request", role: .cancel) {}
        } message: {
            Text("\(model.riderFirstName) won't be charged and will see your reason.")
        }
        .alert("Cancel this ride?", isPresented: $showCancel) {
            TextField("Reason (optional)", text: $reason)
            Button("Cancel ride", role: .destructive) {
                Task { await model.cancel(reason: reason) }
            }
            Button("Keep ride", role: .cancel) {}
        } message: {
            Text("\(model.riderFirstName) gets a full refund and will see your reason.")
        }
        .confirmationDialog("Finish this ride?", isPresented: $confirmComplete, titleVisibility: .visible) {
            Button("Complete ride") {
                Task { await model.complete() }
            }
        } message: {
            Text("Do this once \(model.riderFirstName) is out of the car.")
        }
        .sheet(isPresented: $showChat) {
            ConversationSheet(otherUser: ChatParticipant(
                id: ride.rider.id, displayName: ride.rider.displayName,
                avatarUrl: ride.rider.avatarUrl, isDriver: false))
        }
    }

    // MARK: Bottom bar

    private var hasBottomBar: Bool {
        [.requested, .confirmed, .inProgress].contains(ride.status)
    }

    private var bottomBar: some View {
        // Ticks so "Start ride" turns on by itself 30 minutes before the start.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 10) {
                FormError(message: model.errorMessage)
                switch ride.status {
                case .requested:
                    HStack(spacing: 12) {
                        Button("Decline") {
                            reason = ""
                            showDecline = true
                        }
                        .buttonStyle(.secondary)
                        Button("Confirm") { Task { await model.confirm() } }
                            .buttonStyle(.primary(isLoading: model.busyAction == .confirm))
                    }
                    if let respondBy = ride.respondBy {
                        // A date with style: .relative counts down by itself.
                        Text("\(Image(systemName: "hourglass")) Respond within \(respondBy, style: .relative)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.accentRed)
                    }
                case .confirmed:
                    let canStart = model.canStart(at: context.date)
                    Button("Start ride") { Task { await model.start() } }
                        .buttonStyle(.primary(isLoading: model.busyAction == .start))
                        .disabled(!canStart)
                        .opacity(canStart ? 1 : 0.5)
                    Text(canStart
                         ? "Tap when \(model.riderFirstName) is in the car."
                         : "You can start from \(model.startAvailableAt.formatted(startFormat)).")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                default:
                    Button("Complete ride") { confirmComplete = true }
                        .buttonStyle(.primary(isLoading: model.busyAction == .complete))
                    Text("Ends at \(ride.endsAt.formatted(date: .omitted, time: .shortened)).")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .disabled(model.busyAction != nil)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// "09:30" today, "Sat 09:30" on another day.
    private var startFormat: Date.FormatStyle {
        Calendar.current.isDateInToday(model.startAvailableAt)
            ? .dateTime.hour().minute()
            : .dateTime.weekday(.abbreviated).hour().minute()
    }

    // MARK: Pieces

    @ViewBuilder
    private var meetingPoint: some View {
        let point = ride.meetingPoint
        let address = point.address.flatMap { $0.isEmpty ? nil : $0 }
        HStack {
            LabeledValue(label: "Meeting point", value: address.map { "\(point.type.title): \($0)" } ?? meetingFallback)
            Spacer()
            if let latitude = point.latitude, let longitude = point.longitude {
                smallAction("Maps", systemImage: "map.fill") {
                    if let url = URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)") { openURL(url) }
                }
            }
        }
    }

    /// When there's no address, explain why.
    private var meetingFallback: String {
        let title = ride.meetingPoint.type.title
        switch ride.meetingPoint.type {
        case .riderComesToDriver where ride.status == .requested || ride.status == .awaitingPayment:
            return "\(title). Your address is shared once you confirm."
        case .agreedLocation:
            return "\(title). Not decided yet, sort it out in chat."
        default:
            return title
        }
    }

    @ViewBuilder
    private var reviewForm: some View {
        if model.reviewSent {
            Label("Thanks! Your review was sent.", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.available)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                StarRatingPicker(rating: $model.rating)
                TextField("", text: $model.comment,
                          prompt: Text("How was \(model.riderFirstName) as a passenger?").foregroundStyle(Theme.textSecondary),
                          axis: .vertical)
                    .lineLimit(2...4)
                    .focused($commentFocused)
                    // Return sends the review (a vertical TextField would otherwise add a new line).
                    .submitLabel(.send)
                    .onSubmit { Task { await model.submitReview() } }
                Button("Send review") { Task { await model.submitReview() } }
                    .buttonStyle(.primary(isLoading: model.isSubmittingReview))
                    .disabled(model.rating == 0 || model.isSubmittingReview)
                    .opacity(model.rating == 0 ? 0.5 : 1)
            }
        }
    }

    private func smallAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(ChipStyle(isSelected: false))
    }

    // MARK: Text

    private var whenText: String {
        "\(ride.startsAt.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(ride.startsAt.formatted(date: .omitted, time: .shortened))–\(ride.endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private var paymentText: String {
        let rider = model.riderFirstName
        guard let payment = ride.payment else { return "Price" }
        switch payment.status {
        case .pending: return "Price · \(rider) is still paying"
        case .authorized: return "Price · held on \(rider)'s card, charged when you confirm"
        case .captured: return "Price · paid"
        case .voided: return "Price · released, \(rider) wasn't charged"
        case .refunded: return "Price · refunded to \(rider)"
        case .partiallyRefunded: return "Price · \(payment.refundedAmount.price(payment.currency)) refunded"
        case .failed: return "Price · payment failed"
        }
    }
}

/// The rider at the top of the sheet: photo, name, rating and a chat button.
private struct RiderCard: View {
    let ride: Ride
    let onMessage: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: ride.rider.avatarUrl, placeholder: "person.fill")
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(ride.rider.displayName)
                    .font(.headline)
                Text(ride.rider.ratingText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            CircleIconButton(systemImage: "bubble.left", size: 40,
                             accessibilityLabel: "Message \(ride.rider.displayName)", action: onMessage)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

}

extension RideParticipant {
    /// "★ 4.8 · 12 reviews", or "New rider" before the first review.
    var ratingText: String {
        guard ratingCount > 0 else { return "New rider" }
        let rating = ratingAverage.formatted(.number.precision(.fractionLength(1)))
        return "★ \(rating) · \(ratingCount) \(ratingCount == 1 ? "review" : "reviews")"
    }
}

/// What's going on with the ride and what the driver should do next.
private struct DriverRideBanner: View {
    let ride: Ride
    let riderFirstName: String
    let startAvailableAt: Date

    var body: some View {
        StatusBanner(icon: ride.status.icon, color: ride.status.color, title: title, message: message)
    }

    /// "today", "tomorrow" or the weekday ("Saturday").
    private var dayText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(ride.startsAt) { return "today" }
        if calendar.isDateInTomorrow(ride.startsAt) { return "tomorrow" }
        return ride.startsAt.formatted(.dateTime.weekday(.wide))
    }

    private var title: String {
        switch ride.status {
        case .awaitingPayment: "Payment in progress"
        case .requested: "New ride request"
        case .confirmed: "Confirmed"
        case .inProgress: "Ride in progress"
        case .completed: "Ride completed"
        case .declined: "You declined this ride"
        case .cancelled: ride.cancelledByMe == true ? "You cancelled this ride" : "\(riderFirstName) cancelled"
        case .expired: "Request expired"
        }
    }

    private var message: String {
        switch ride.status {
        case .awaitingPayment:
            return "\(riderFirstName) is finishing payment. The request shows up once it's done."
        case .requested:
            if let respondBy = ride.respondBy {
                return "Confirm by \(respondBy.formatted(.dateTime.weekday(.abbreviated).hour().minute())) or the request expires. \(riderFirstName) is charged when you confirm."
            }
            return "\(riderFirstName) is charged when you confirm."
        case .confirmed:
            return "Meet \(riderFirstName) \(dayText) at \(ride.startsAt.formatted(date: .omitted, time: .shortened)). You can start the ride from \(startAvailableAt.formatted(date: .omitted, time: .shortened))."
        case .inProgress:
            return "Enjoy the drive! It ends at \(ride.endsAt.formatted(date: .omitted, time: .shortened))."
        case .completed:
            return ride.canReview ? "Nice one. Let other drivers know how \(riderFirstName) was." : "Nice one!"
        case .declined:
            let reason = ride.declineReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return "\(reason)\(riderFirstName) wasn't charged."
        case .cancelled:
            let money: String = switch ride.payment?.status {
            case .refunded: "\(riderFirstName) got a full refund."
            case .voided: "\(riderFirstName) wasn't charged."
            case .captured: "It was a late cancellation, so you still get paid."
            default: ""
            }
            let reason = ride.cancellationReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return "\(reason)\(money)"
        case .expired:
            return "You didn't respond in time. \(riderFirstName) wasn't charged."
        }
    }
}
