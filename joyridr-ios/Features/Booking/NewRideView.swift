import SwiftUI

/// "NEW RIDE": pick a day, duration and start time, choose where to meet, and send the request.
/// Opens from the car's row in Explore with a zoom transition.
struct NewRideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: NewRideModel
    @State private var showDetails = false

    init(car: NearbyCar) {
        _model = State(initialValue: NewRideModel(car: car))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let ride = model.createdRide {
                    RequestSentView(ride: ride, timeZone: model.timeZone) { dismiss() }
                } else {
                    form
                }
            }
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.createdRide == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("New ride").displayTitle(18)
                    }
                }
            }
        }
        .task { await model.loadSchedule() }
        .sheet(isPresented: $showDetails) {
            CarInfoSheet(carID: model.car.car.id, driverID: model.car.driver.id)
        }
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                carSummary

                BookingSection("Choose date & time") {
                    VStack(alignment: .leading, spacing: 18) {
                        dayStrip
                        durationPicker
                        slotGrid
                    }
                }

                BookingSection("Meeting point") {
                    meetingPointOptions
                }

                BookingSection("Note to driver") {
                    TextField("", text: $model.note, prompt: Text("Anything \(model.car.driver.firstName) should know?").foregroundStyle(Theme.textSecondary), axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bottomBar }
        // Reloads the free times whenever the day or duration changes, and cancels the previous load.
        .task(id: model.slotsQuery) { await model.loadSlots() }
        .animation(.snappy, value: model.selectedSlot)
        .animation(.snappy, value: model.meetingPoint)
    }

    /// Compact car summary with the button that opens the full car and driver details.
    private var carSummary: some View {
        HStack(spacing: 14) {
            RemoteImage(path: model.car.car.photoUrl ?? model.car.driver.avatarUrl)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(model.car.car.name)
                    .font(.headline)
                Text("\(model.car.driver.displayName) · \(model.car.driver.ratingText)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            CircleIconButton(systemImage: "info", size: 40, accessibilityLabel: "Car and driver details") {
                showDetails = true
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var dayStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.days, id: \.self) { day in
                    let isWorking = model.isWorkingDay(day)
                    Button {
                        model.selectedDay = day
                    } label: {
                        VStack(spacing: 4) {
                            Text(model.format(day, .dateTime.weekday(.abbreviated)))
                                .font(.caption.weight(.semibold))
                            Text(model.format(day, .dateTime.day()))
                                .font(.title3.weight(.bold))
                        }
                        .frame(width: 52, height: 64)
                        .background(day == model.selectedDay ? Theme.brandRed : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 16))
                        .opacity(isWorking ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isWorking)
                    .accessibilityLabel(model.format(day, .dateTime.weekday(.wide).day().month(.wide)))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var durationPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(NewRideModel.durations, id: \.self) { minutes in
                    Button(durationLabel(minutes)) { model.duration = minutes }
                        .buttonStyle(ChipStyle(isSelected: model.duration == minutes))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var slotGrid: some View {
        switch model.slotsState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 60)
        case let .failed(message):
            VStack(spacing: 10) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                Button("Try again") { Task { await model.loadSlots() } }
                    .buttonStyle(ChipStyle(isSelected: false))
            }
            .frame(maxWidth: .infinity)
        case .loaded where model.slots.isEmpty:
            Text("No free times on this day. Try another day or a shorter ride.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        case .loaded:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                ForEach(model.slots) { slot in
                    Button(model.format(slot.startsAt, .dateTime.hour().minute())) {
                        model.selectedSlot = slot
                    }
                    .buttonStyle(ChipStyle(isSelected: model.selectedSlot == slot, fillsWidth: true))
                }
            }
        }
    }

    private var meetingPointOptions: some View {
        let driver = model.car.driver.firstName
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(MeetingPointType.allCases, id: \.self) { option in
                Button {
                    model.meetingPoint = option
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: model.meetingPoint == option ? "largecircle.fill.circle" : "circle")
                            .font(.title3)
                            .foregroundStyle(model.meetingPoint == option ? Theme.accentRed : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.riderTitle(driver: driver))
                                .font(.body.weight(.semibold))
                            Text(option.riderSubtitle(driver: driver))
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if model.meetingPoint != .riderComesToDriver {
                TextField("", text: $model.address, prompt: Text(model.meetingPoint == .driverComesToRider
                    ? "Address or landmark (optional)" : "Suggested spot (optional)").foregroundStyle(Theme.textSecondary))
                    .textContentType(.fullStreetAddress)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let slot = model.selectedSlot {
                HStack {
                    Text("\(model.format(slot.startsAt, .dateTime.weekday(.abbreviated).day().month(.abbreviated))), \(model.format(slot.startsAt, .dateTime.hour().minute()))–\(model.format(slot.endsAt, .dateTime.hour().minute()))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(model.totalPrice.price(model.car.car.currency))
                        .font(.headline)
                }
                .transition(.opacity)
            }

            FormError(message: model.errorMessage)

            Button(model.selectedSlot == nil ? "Pick a time" : "Request ride · \(model.totalPrice.price(model.car.car.currency))") {
                Task { await model.requestRide() }
            }
            .buttonStyle(.primary(isLoading: model.isSubmitting))
            .disabled(!model.canSubmit)
            .opacity(model.selectedSlot == nil ? 0.5 : 1)

            Text("You're only charged once \(model.car.driver.firstName) confirms. Free cancellation up to 24 h before the ride.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

/// Section with a display-font title and a grey card, like "CHOOSE DATE & TIME" in the design.
struct BookingSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .displayTitle(15)
                .accessibilityAddTraits(.isHeader)
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }
}

/// Small selectable capsule: durations and start times.
struct ChipStyle: ButtonStyle {
    let isSelected: Bool
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 38)
            .background(isSelected ? Theme.brandRed : Color.white.opacity(0.08), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
