import SwiftUI

/// Colours, fonts and sizes from the Figma designs. Change them here and the whole app follows.
enum Theme {
    // MARK: Colours
    static let background = Color.black
    /// Primary buttons and racing stripes.
    static let brandRed = Color(red: 0.66, green: 0.15, blue: 0.12)        // #A8261E
    /// Brighter red for small accents: selected tab, toggles, badges.
    static let accentRed = Color(red: 0.88, green: 0.28, blue: 0.24)       // #E0483E
    /// The dark red glow behind cards.
    static let glowRed = Color(red: 0.36, green: 0.06, blue: 0.05)
    static let card = Color(white: 0.23)                                   // #3A3A3A
    static let field = Color(white: 0.24)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let available = Color(red: 0.45, green: 0.95, blue: 0.35)

    // MARK: Fonts
    /// BBH Bartle, the display font used for the wordmark and section titles.
    /// Registered under "Fonts provided by application" in the target's Info settings.
    static func display(_ size: CGFloat) -> Font {
        .custom("BBHBartle-Regular", size: size, relativeTo: .largeTitle)
    }

    // MARK: Sizes
    static let horizontalPadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let fieldHeight: CGFloat = 52
}

extension View {
    /// Section title in the display font, e.g. "AVAILABLE DRIVERS".
    func displayTitle(_ size: CGFloat = 18) -> some View {
        font(Theme.display(size)).textCase(.uppercase).foregroundStyle(Theme.textPrimary)
    }
}
