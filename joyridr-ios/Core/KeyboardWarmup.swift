import UIKit

/// The first time a text field is focused, iOS loads its whole keyboard system, which froze the login
/// screen for half a second or more before the keyboard came up. Doing that once at launch, behind the
/// splash screen, makes the first tap on a field as quick as the rest.
@MainActor
enum KeyboardWarmup {
    private static var done = false

    static func run() async {
        guard !done else { return }
        done = true
        // At launch the window can take a moment to appear; give it up to two seconds.
        var window = keyWindow
        var attempts = 0
        while window == nil && attempts < 20 {
            try? await Task.sleep(for: .milliseconds(100))
            window = keyWindow
            attempts += 1
        }
        guard let window else { return }
        // An off-screen field that takes focus and gives it straight back: the keyboard never shows,
        // but everything behind it gets loaded.
        let field = UITextField(frame: CGRect(x: -100, y: -100, width: 10, height: 10))
        field.autocorrectionType = .no
        window.addSubview(field)
        field.becomeFirstResponder()
        // Let iOS start setting the keyboard up, then hand focus back before it slides in.
        DispatchQueue.main.async {
            field.resignFirstResponder()
            field.removeFromSuperview()
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
