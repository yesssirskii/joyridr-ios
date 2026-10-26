import SwiftUI

/// The diagonal red stripes from the designs. Put it behind content with `.background { RacingStripes() }`.
struct RacingStripes: View {
    var count = 4
    var lineWidth: CGFloat = 14
    var spacing: CGFloat = 38
    /// Where the first stripe crosses the top edge, as a fraction of the width.
    var startX: CGFloat = -0.35
    /// How far down the screen the stripes reach, as a fraction of the height.
    var length: CGFloat = 0.75
    var color = Theme.brandRed

    var body: some View {
        Canvas { context, size in
            for index in 0..<count {
                let x = size.width * startX + CGFloat(index) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: -20))
                // Steep diagonal towards the bottom right, like in Figma (about 55°).
                path.addLine(to: CGPoint(x: x + size.height * length * 0.7, y: size.height * length))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The dark red glow used behind the car list and sheets.
struct RedGlow: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.08, green: 0.02, blue: 0.02), location: 0),
                .init(color: Theme.glowRed, location: 0.45),
                .init(color: Color(red: 0.08, green: 0.02, blue: 0.02), location: 0.9),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    ZStack {
        Theme.background
        RacingStripes()
    }
    .ignoresSafeArea()
}
