import SwiftUI
import AppKit

/// Interface language. Arabic is the source text; English comes from `L10n.en`.
/// Switching language relaunches the app, so everything (including static lists) picks it up.
enum Lang {
    static let code: String = UserDefaults.standard.string(forKey: "language") ?? "ar"
    static var en: Bool { code == "en" }
    static var dir: LayoutDirection { en ? .leftToRight : .rightToLeft }
    static var locale: Locale { Locale(identifier: en ? "en_US" : "ar_EG") }
}

/// Translate a fixed Arabic phrase.
func tr(_ s: String) -> String { Lang.en ? (L10n.en[s] ?? s) : s }

/// Translate an Arabic phrase with `%@` slots, filled in order.
func trf(_ key: String, _ args: Any...) -> String {
    let fmt = Lang.en ? (L10n.en[key] ?? key) : key
    var out = ""
    var rest = Substring(fmt)
    var i = 0
    while let r = rest.range(of: "%@") {
        out += rest[..<r.lowerBound]
        if i < args.count { out += "\(args[i])" }
        i += 1
        rest = rest[r.upperBound...]
    }
    return out + rest
}

extension Lang {
    /// Saves the choice and restarts the app so every screen and list uses it.
    static func switchTo(_ code: String) {
        guard code != Lang.code else { return }
        UserDefaults.standard.set(code, forKey: "language")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-n", Bundle.main.bundlePath]
        try? p.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }
}
