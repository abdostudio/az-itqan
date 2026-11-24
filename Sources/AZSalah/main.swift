import AppKit

// `--print-times [cityID] [yyyy-mm-dd]` prints the calculated times and exits (used for checks).
if let i = CommandLine.arguments.firstIndex(of: "--print-times") {
    let args = Array(CommandLine.arguments.dropFirst(i + 1))
    let settings = AppSettings.shared
    let city = args.first.flatMap(Cities.byID) ?? Cities.byID(settings.cityID) ?? Cities.all[0]
    var date = Date()
    if args.count > 1 {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = city.location.timeZone
        date = f.date(from: args[1]).map { $0.addingTimeInterval(12 * 3600) } ?? date
    }
    let calc = PrayerCalculator(location: city.location, method: CalcMethod.byID(city.method),
                                asr: .shafi, highLat: .angleBased, offsets: [:])
    let times = calc.times(for: date)
    let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = city.location.timeZone
    print("\(city.id) [\(city.method)] \(Hijri.string(date))")
    for p in Prayer.allCases { print("  \(p.rawValue): \(times[p].map(f.string) ?? "-")") }
    print("  fasting tomorrow: \(Fasting.reasons(for: date.addingTimeInterval(86400), hijriAdjust: 0).map(\.title))")
    exit(0)
}

// `--snapshot <dir>` renders every screen to PNG files (design review without screen recording).
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
    _ = NSApplication.shared
    MainActor.assumeIsolated { Snapshots.render(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--notch-demo"), CommandLine.arguments.count > i + 1 {
    _ = NSApplication.shared
    MainActor.assumeIsolated { NotchDemo.render(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--video"), CommandLine.arguments.count > i + 1 {
    _ = NSApplication.shared
    let preview = CommandLine.arguments.contains("--preview")
    MainActor.assumeIsolated { PromoVideo.vertical = CommandLine.arguments.contains("--vertical") }
    MainActor.assumeIsolated { PromoVideo.render(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]), previewOnly: preview) }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--mockups"), CommandLine.arguments.count > i + 1 {
    _ = NSApplication.shared
    MainActor.assumeIsolated {
        let u = URL(fileURLWithPath: CommandLine.arguments[i + 1])
        Mockups.render(to: u)
        LockMockups.render(to: u)
    }
    exit(0)
}

if let i = CommandLine.arguments.firstIndex(of: "--make-icon"), CommandLine.arguments.count > i + 1 {
    _ = NSApplication.shared
    MainActor.assumeIsolated { Snapshots.icon(to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
