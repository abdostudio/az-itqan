import Foundation
import Combine

/// All user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    // Location
    @Published var cityID: String { didSet { d.set(cityID, forKey: "cityID") } }
    @Published var gpsLocation: Location? { didSet { save(gpsLocation, "gpsLocation") } }

    // Calculation
    @Published var methodID: String { didSet { d.set(methodID, forKey: "methodID") } }
    @Published var asrSchool: AsrSchool { didSet { d.set(asrSchool.rawValue, forKey: "asrSchool") } }
    @Published var highLat: HighLatRule { didSet { d.set(highLat.rawValue, forKey: "highLat") } }
    @Published var offsets: [String: Int] { didSet { d.set(offsets, forKey: "offsets") } }
    @Published var hijriAdjust: Int { didSet { d.set(hijriAdjust, forKey: "hijriAdjust") } }

    // Prayer lock
    @Published var lockEnabled: Bool { didSet { d.set(lockEnabled, forKey: "lockEnabled") } }
    @Published var lockPrayers: [String] { didSet { d.set(lockPrayers, forKey: "lockPrayers") } }
    @Published var lockMinutes: Int { didSet { d.set(lockMinutes, forKey: "lockMinutes") } }
    @Published var doneAfterMinutes: Int { didSet { d.set(doneAfterMinutes, forKey: "doneAfterMinutes") } }
    @Published var snoozeMinutes: Int { didSet { d.set(snoozeMinutes, forKey: "snoozeMinutes") } }
    @Published var maxSnoozes: Int { didSet { d.set(maxSnoozes, forKey: "maxSnoozes") } }
    /// Snoozing is only offered during the first N minutes after the adhan.
    @Published var snoozeWindowMinutes: Int { didSet { d.set(snoozeWindowMinutes, forKey: "snoozeWindowMinutes") } }
    /// After an emergency, lock again after this many minutes (once).
    @Published var followUpMinutes: Int { didSet { d.set(followUpMinutes, forKey: "followUpMinutes") } }
    @Published var deferInMeetings: Bool { didSet { d.set(deferInMeetings, forKey: "deferInMeetings") } }

    // Alerts
    @Published var preAlertMinutes: Int { didSet { d.set(preAlertMinutes, forKey: "preAlertMinutes") } }
    @Published var reminderMinutes: Int { didSet { d.set(reminderMinutes, forKey: "reminderMinutes") } }
    @Published var palestineReminders: Bool { didSet { d.set(palestineReminders, forKey: "palestineReminders") } }
    @Published var wirdEnabled: Bool { didSet { d.set(wirdEnabled, forKey: "wirdEnabled") } }
    @Published var wirdPages: Int { didSet { d.set(wirdPages, forKey: "wirdPages") } }
    @Published var wirdAfter: String { didSet { d.set(wirdAfter, forKey: "wirdAfter") } }
    /// The user explicitly picked/confirmed their city (new installs don't lock the screen until then).
    @Published var locationConfirmed: Bool { didSet { d.set(locationConfirmed, forKey: "locationConfirmed") } }
    @Published var duhaReminder: Bool { didSet { d.set(duhaReminder, forKey: "duhaReminder") } }
    @Published var qiyamReminder: Bool { didSet { d.set(qiyamReminder, forKey: "qiyamReminder") } }
    @Published var sadaqaReminder: String { didSet { d.set(sadaqaReminder, forKey: "sadaqaReminder") } }
    /// Island attached to the notch (false) or free-floating anywhere (true).
    @Published var islandFloating: Bool { didSet { d.set(islandFloating, forKey: "islandFloating") } }
    /// Proportional size of the floating island (0.8 … 1.5).
    @Published var islandScale: Double { didSet { d.set(islandScale, forKey: "islandScale") } }
    @Published var adhkarReminders: Bool { didSet { d.set(adhkarReminders, forKey: "adhkarReminders") } }
    @Published var fastingReminders: Bool { didSet { d.set(fastingReminders, forKey: "fastingReminders") } }
    /// Idle notch: "slim" = exactly the camera housing (covers nothing), "wings" = prayer + countdown beside it.
    @Published var buddyEnabled: Bool { didSet { d.set(buddyEnabled, forKey: "buddyEnabled") } }
    @Published var buddyName: String { didSet { d.set(buddyName, forKey: "buddyName") } }
    @Published var buddyPhone: String { didSet { d.set(buddyPhone, forKey: "buddyPhone") } }
    @Published var rahimReminders: Bool { didSet { d.set(rahimReminders, forKey: "rahimReminders") } }
    @Published var rahimWeekly: Bool { didSet { d.set(rahimWeekly, forKey: "rahimWeekly") } }
    @Published var rahimSeasons: Bool { didSet { d.set(rahimSeasons, forKey: "rahimSeasons") } }
    @Published var idleStyle: String { didSet { d.set(idleStyle, forKey: "idleStyle") } }
    /// 0 = idle notch is exactly the camera, 1 = prayer name + countdown beside it.
    @Published var idleWidth: Double { didSet { d.set(idleWidth, forKey: "idleWidth") } }
    /// Idle notch: 0 fuel line under the camera · 1 dot · 2 small text · 3 full (prayer + countdown).
    @Published var idleLevel: Int { didSet { d.set(idleLevel, forKey: "idleLevel") } }
    @Published var alwaysShowDhikr: Bool { didSet { d.set(alwaysShowDhikr, forKey: "alwaysShowDhikr") } }
    @Published var peekSeconds: Int { didSet { d.set(peekSeconds, forKey: "peekSeconds") } }
    @Published var displayMode: String { didSet { d.set(displayMode, forKey: "displayMode") } }
    @Published var announcePrayer: Bool { didSet { d.set(announcePrayer, forKey: "announcePrayer") } }
    @Published var adhanVolume: Double { didSet { d.set(adhanVolume, forKey: "adhanVolume") } }
    @Published var soundEnabled: Bool { didSet { d.set(soundEnabled, forKey: "soundEnabled") } }
    @Published var soundName: String { didSet { d.set(soundName, forKey: "soundName") } }
    @Published var customSoundPath: String { didSet { d.set(customSoundPath, forKey: "customSoundPath") } }

    private init() {
        d.register(defaults: [
            "cityID": "cairo", "methodID": "egypt", "asrSchool": "shafi", "highLat": "angleBased",
            "hijriAdjust": 0, "lockEnabled": true, "lockPrayers": Prayer.fard.map(\.rawValue),
            "lockMinutes": 10, "doneAfterMinutes": 3, "snoozeMinutes": 5, "maxSnoozes": 1, "snoozeWindowMinutes": 10, "followUpMinutes": 20,
            "deferInMeetings": true, "preAlertMinutes": 10, "reminderMinutes": 10,
            "palestineReminders": true, "adhkarReminders": true, "sadaqaReminder": "daily", "duhaReminder": true, "qiyamReminder": true, "islandFloating": false, "islandScale": 1.0, "wirdEnabled": true, "wirdPages": 4, "wirdAfter": "fajr", "fastingReminders": true, "soundEnabled": true,
            "soundName": "adhan-mix", "announcePrayer": true, "adhanVolume": 0.8, "customSoundPath": "", "peekSeconds": 7, "alwaysShowDhikr": false, "idleStyle": "slim", "idleWidth": 0.4, "idleLevel": 0, "rahimReminders": true, "buddyEnabled": true, "buddyName": "", "buddyPhone": "", "rahimWeekly": true, "rahimSeasons": true, "displayMode": "all",
        ])
        cityID = d.string(forKey: "cityID") ?? "cairo"
        gpsLocation = Self.load("gpsLocation")
        methodID = d.string(forKey: "methodID") ?? "egypt"
        asrSchool = AsrSchool(rawValue: d.string(forKey: "asrSchool") ?? "") ?? .shafi
        highLat = HighLatRule(rawValue: d.string(forKey: "highLat") ?? "") ?? .angleBased
        offsets = d.dictionary(forKey: "offsets") as? [String: Int] ?? [:]
        hijriAdjust = d.integer(forKey: "hijriAdjust")
        lockEnabled = d.bool(forKey: "lockEnabled")
        lockPrayers = d.stringArray(forKey: "lockPrayers") ?? []
        lockMinutes = d.integer(forKey: "lockMinutes")
        doneAfterMinutes = d.integer(forKey: "doneAfterMinutes")
        snoozeMinutes = d.integer(forKey: "snoozeMinutes")
        maxSnoozes = min(2, d.integer(forKey: "maxSnoozes"))
        snoozeWindowMinutes = d.integer(forKey: "snoozeWindowMinutes")
        followUpMinutes = d.integer(forKey: "followUpMinutes")
        deferInMeetings = d.bool(forKey: "deferInMeetings")
        preAlertMinutes = d.integer(forKey: "preAlertMinutes")
        reminderMinutes = d.integer(forKey: "reminderMinutes")
        palestineReminders = d.bool(forKey: "palestineReminders")
        fastingReminders = d.bool(forKey: "fastingReminders")
        adhkarReminders = d.bool(forKey: "adhkarReminders")
        sadaqaReminder = d.string(forKey: "sadaqaReminder") ?? "daily"
        duhaReminder = d.bool(forKey: "duhaReminder")
        qiyamReminder = d.bool(forKey: "qiyamReminder")
        // Existing installs (already onboarded) count as confirmed; the time-zone check still protects them.
        locationConfirmed = d.object(forKey: "locationConfirmed") != nil ? d.bool(forKey: "locationConfirmed") : d.bool(forKey: "onboarded")
        islandFloating = d.bool(forKey: "islandFloating")
        islandScale = min(1.5, max(0.8, d.double(forKey: "islandScale")))
        wirdEnabled = d.bool(forKey: "wirdEnabled")
        wirdPages = max(1, d.integer(forKey: "wirdPages"))
        wirdAfter = d.string(forKey: "wirdAfter") ?? "fajr"
        alwaysShowDhikr = d.bool(forKey: "alwaysShowDhikr")
        idleStyle = d.string(forKey: "idleStyle") ?? "slim"
        rahimReminders = d.bool(forKey: "rahimReminders")
        buddyEnabled = d.bool(forKey: "buddyEnabled")
        buddyName = d.string(forKey: "buddyName") ?? ""
        buddyPhone = d.string(forKey: "buddyPhone") ?? ""
        rahimWeekly = d.bool(forKey: "rahimWeekly")
        rahimSeasons = d.bool(forKey: "rahimSeasons")
        idleWidth = min(1, max(0, d.double(forKey: "idleWidth")))
        idleLevel = min(3, max(0, d.integer(forKey: "idleLevel")))
        peekSeconds = d.integer(forKey: "peekSeconds")
        displayMode = d.string(forKey: "displayMode") ?? "all"
        announcePrayer = d.bool(forKey: "announcePrayer")
        adhanVolume = d.double(forKey: "adhanVolume")
        soundEnabled = d.bool(forKey: "soundEnabled")
        soundName = d.string(forKey: "soundName") ?? "adhan-mix"
        customSoundPath = d.string(forKey: "customSoundPath") ?? ""
    }

    /// The chosen city's clock matches this Mac's clock right now.
    var timeZoneMatches: Bool {
        let now = Date()
        return location.timeZone.secondsFromGMT(for: now) == TimeZone.current.secondsFromGMT(for: now)
    }

    var location: Location {
        if cityID == "gps", let g = gpsLocation { return g }
        return (Cities.byID(cityID) ?? Cities.all[0]).location
    }

    var calculator: PrayerCalculator {
        var o: [Prayer: Int] = [:]
        for (k, v) in offsets { if let p = Prayer(rawValue: k) { o[p] = v } }
        return PrayerCalculator(location: location, method: CalcMethod.byID(methodID),
                                asr: asrSchool, highLat: highLat, offsets: o)
    }

    func locks(_ p: Prayer) -> Bool { lockEnabled && lockPrayers.contains(p.rawValue) }

    func toggleLock(_ p: Prayer, _ on: Bool) {
        var s = Set(lockPrayers)
        if on { s.insert(p.rawValue) } else { s.remove(p.rawValue) }
        lockPrayers = Prayer.fard.map(\.rawValue).filter { s.contains($0) }
    }

    private func save<T: Encodable>(_ v: T?, _ key: String) {
        if let v, let data = try? JSONEncoder().encode(v) { d.set(data, forKey: key) } else { d.removeObject(forKey: key) }
    }
    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
