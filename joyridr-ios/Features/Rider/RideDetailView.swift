import SwiftUI

/// Everything about one booking: status, when and where, payment, and what the rider can do next.
/// Opens from the ride's row in My rides with a zoom transition.
struct RideDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: RideDetailModel
    @State private var showCarInfo = false
    @State private var confirmCancel = false
    @State private var showChat = false
    @FocusState private var commentFocused: Bool

    init(ride: Ride) {
        _model = State(initialValue: RideDetailModel(ride: ride))
    }

    private var ride: Ride { model.ride }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CarSummaryCard(
                        photoPath: ride.car.photoUrl ?? ride.driver.avatarUrl,
                        title: ride.car.name,
                        subtitle: "\(ride.driver.displayName) · \(driverRatingText)",
                        onInfo: { showCarInfo = true })

                    RideStatusBanner(ride: ride, driverFirstName: model.driverFirstName)

                    BookingSection("Ride details") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledValue(label: "When", value: whenText)
                            LabeledValue(label: "Duration", value: durationLabel(ride.durationMinutes))
                            meetingPoint
                            if let phone = ride.driver.phoneNumber {
                                HStack {
                                    LabeledValue(label: "\(model.driverFirstName)'s phone", value: phone)
                                    Spacer()
                                    smallAction("Call", systemImage: "phone.fill") {
                                        if let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") { openURL(url) }
                                    }
                                }
                            }
                            if let note = ride.riderNote, !note.isEmpty {
                                LabeledValue(label: "Your note", value: note)
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
                        BookingSection("Rate your ride") {
                            reviewForm
                        }
                    }

                    FormError(message: model.errorMessage)

                    actions
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your ride").displayTitle(18)
                }
                // The keyboard covers "Send review", so give it a way out.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { commentFocused = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .refreshable { await model.refresh() }
            .animation(.snappy, value: ride)
            .animation(.snappy, value: model.reviewSent)
        }
        .task { await model.refresh() }
        .sheet(isPresented: $showCarInfo) {
            CarInfoSheet(carID: ride.car.id, driverID: ride.driver.id)
        }
        .confirmationDialog("Cancel this ride?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel ride", role: .destructive) {
                Task { await model.cancel() }
            }
            Button("Keep ride", role: .cancel) {}
        } message: {
            Text(model.cancelConsequence)
        }
        .sheet(isPresented: $showChat) {
            ConversationSheet(otherUser: ChatParticipant(
                id: ride.driver.id, displayName: ride.driver.displayName,
                avatarUrl: ride.driver.avatarUrl, isDriver: true))
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var meetingPoint: some View {
        let point = ride.meetingPoint
        let title = point.type.riderTitle(driver: model.driverFirstName)
        let address = point.address.flatMap { $0.isEmpty ? nil : $0 }
        HStack {
            LabeledValue(label: "Meeting point", value: address.map { "\(title): \($0)" } ?? meetingFallback(title))
            Spacer()
            if let latitude = point.latitude, let longitude = point.longitude {
                smallAction("Maps", systemImage: "map.fill") {
                    if let url = URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)") { openURL(url) }
                }
            }
        }
    }

    /// When there's no address yet, explain why.
    private func meetingFallback(_ title: String) -> String {
        switch ride.meetingPoint.type {
        case .riderComesToDriver where ride.status == .requested || ride.status == .awaitingPayment:
            "\(title). The address appears once \(model.driverFirstName) confirms."
        case .agreedLocation:
            "\(title). Not decided yet."
        default:
            title
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
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            model.rating = star
                        } label: {
                            Image(systemName: star <= model.rating ? "star.fill" : "star")
                                .font(.title)
                                .foregroundStyle(star <= model.rating ? Theme.accentRed : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    }
                }
                TextField("", text: $model.comment,
                          prompt: Text("How was the ride with \(model.driverFirstName)?").foregroundStyle(Theme.textSecondary),
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

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showChat = true
            } label: {
                Label("Message \(model.driverFirstName)", systemImage: "bubble.left.fill")
            }
            .buttonStyle(.secondary)

            if model.canCancel {
                Button(role: .destructive) {
                    confirmCancel = true
                } label: {
                    if model.isCancelling {
                        ProgressView().tint(.white)
                    } else {
                        Text("Cancel ride").foregroundStyle(Theme.accentRed)
                    }
                }
                .buttonStyle(.secondary)
                .disabled(model.isCancelling)
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

    private var driverRatingText: String {
        ride.driver.ratingCount == 0
            ? "New"
            : "★ \(ride.driver.ratingAverage.formatted(.number.precision(.fractionLength(1)))) (\(ride.driver.ratingCount))"
    }

    private var whenText: String {
        "\(ride.startsAt.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(ride.startsAt.formatted(date: .omitted, time: .shortened))–\(ride.endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private var paymentText: String {
        guard let payment = ride.payment else { return "Price" }
        switch payment.status {
        case .pending: return "Price · payment not finished"
        case .authorized: return "Price · held, not charged yet"
        case .captured: return "Price · paid"
        case .voided: return "Price · released, you weren't charged"
        case .refunded: return "Price · refunded"
        case .partiallyRefunded: return "Price · \(payment.refundedAmount.price(payment.currency)) refunded"
        case .failed: return "Price · payment failed"
        }
    }
}

/// Coloured banner at the top of the ride: what's going on and what happens next.
private struct RideStatusBanner: View {
    let ride: Ride
    let driverFirstName: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch ride.status {
        case .awaitingPayment: "creditcard"
        case .requested: "hourglass"
        case .confirmed: "checkmark.seal.fill"
        case .inProgress: "flag.checkered"
        case .completed: "trophy.fill"
        case .declined, .cancelled: "xmark.circle.fill"
        case .expired: "clock.badge.xmark"
        }
    }

    private var color: Color {
        switch ride.status {
        case .confirmed, .completed: Theme.available
        case .inProgress: .yellow
        case .requested, .awaitingPayment: .orange
        case .declined, .cancelled, .expired: Theme.textSecondary
        }
    }

    private var title: String {
        switch ride.status {
        case .awaitingPayment: "Finishing payment"
        case .requested: "Waiting for \(driverFirstName)"
        case .confirmed: "Confirmed!"
        case .inProgress: "Ride in progress"
        case .completed: "Ride completed"
        case .declined: "Declined"
        case .cancelled: ride.cancelledByMe == true ? "You cancelled this ride" : "\(driverFirstName) cancelled"
        case .expired: "Request expired"
        }
    }

    private var message: String {
        switch ride.status {
        case .awaitingPayment:
            return "Your payment is being processed."
        case .requested:
            if let respondBy = ride.respondBy {
                return "\(driverFirstName) has until \(respondBy.formatted(.dateTime.weekday(.abbreviated).hour().minute())) to confirm. You won't be charged until then."
            }
            return "\(driverFirstName) will confirm soon. You won't be charged until then."
        case .confirmed:
            return "See you \(ride.startsAt.formatted(.dateTime.weekday(.wide))) at \(ride.startsAt.formatted(date: .omitted, time: .shortened)). Free cancellation until 24 h before."
        case .inProgress:
            return "Enjoy the \(ride.car.name)! Ends at \(ride.endsAt.formatted(date: .omitted, time: .shortened))."
        case .completed:
            return ride.canReview ? "Hope it was a blast. Let \(driverFirstName) know how it went." : "Hope it was a blast!"
        case .declined:
            let reason = ride.declineReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return "\(reason)\(driverFirstName) couldn't take this ride. You haven't been charged."
        case .cancelled:
            let refund: String = switch ride.payment?.status {
            case .refunded: "You got a full refund."
            case .voided: "You weren't charged."
            case .captured: "This late cancellation wasn't refunded."
            default: ""
            }
            let reason = ride.cancellationReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return "\(reason)\(refund)"
        case .expired:
            return "\(driverFirstName) didn't respond in time. You haven't been charged."
        }
    }
}
