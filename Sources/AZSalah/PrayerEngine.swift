import Foundation
import Combine

/// Keeps today's times fresh and fires prayer events at the right moments.
final class PrayerEngine: ObservableObject {
    @Published private(set) var today: [Prayer: Date] = [:]
    @Published private(set) var tomorrow: [Prayer: Date] = [:]
    @Published private(set) var yesterdayIsha: Date?
    /// Updated every second, but views are only told once a minute while the notch is idle (keeps it light).
    var now = Date() {
        didSet {
            let m = Int(now.timeIntervalSince1970 / 60)
            if liveSeconds || m != lastMinute || (next.time.timeIntervalSince(now) < 120) {
                lastMinute = m
                objectWillChange.send()
            }
        }
    }
    private var lastMinute = 0
    /// Set by the notch while it's open or showing an alert.
    var liveSeconds = false
    /// Days until 1 Ramadan (0 during Ramadan) and the day inside Ramadan — computed once a day.
    @Published private(set) var ramadanDays = 0
    @Published private(set) var ramadanDay: Int?

    var onAdhan: ((Prayer, Date) -> Void)?
    var onPreAlert: ((Prayer, Date) -> Void)?
    var onReminder: ((Msg, Bool) -> Void)?
    var onFasting: (([FastingDay]) -> Void)?
    var onAdhkar: ((MorningEvening.Kind) -> Void)?
    var onWird: (() -> Void)?
    var onSadaqa: (() -> Void)?
    var onNafl: ((Nafl) -> Void)?
    var onRahim: ((UUID?, Msg) -> Void)?

    let settings: AppSettings
    private var timer: Timer?
    private var dayKey = ""
    private var fired: Set<String> = []
    private var lastReminder = Date()
    private var reminderCount = 0
    private var bag: Set<AnyCancellable> = []

    init(settings: AppSettings) {
        self.settings = settings
        let stored = UserDefaults.standard.stringArray(forKey: "fired") ?? []
        fired = Set(stored)
        recompute()
        // Recalculate whenever anything that affects the times changes.
        settings.objectWillChange
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] in self?.recompute() }
            .store(in: &bag)
    }

    func start() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    var tz: TimeZone { settings.location.timeZone }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = tz; return c
    }

    func recompute() {
        let calc = settings.calculator
        let cal = calendar
        now = Date()
        today = calc.times(for: now)
        tomorrow = calc.times(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        yesterdayIsha = calc.times(for: cal.date(byAdding: .day, value: -1, to: now) ?? now)[.isha]
        let c = cal.dateComponents([.year, .month, .day], from: now)
        let key = "\(c.year!)-\(c.month!)-\(c.day!)"
        ramadanDays = RamadanPlan.daysUntil(from: now, adjust: settings.hijriAdjust)
        ramadanDay = RamadanPlan.dayOfRamadan(now, adjust: settings.hijriAdjust)
        if key != dayKey {
            dayKey = key
            fired = fired.filter { $0.hasSuffix(key) }
            persistFired()
        }
    }

    // MARK: derived state

    /// Next obligatory prayer and its time.
    var next: (prayer: Prayer, time: Date) {
        for p in Prayer.fard { if let t = today[p], t > now { return (p, t) } }
        return (.fajr, tomorrow[.fajr] ?? now.addingTimeInterval(3600))
    }

    /// The prayer whose time we're currently in.
    var current: (prayer: Prayer, time: Date)? {
        var last: (Prayer, Date)?
        for p in Prayer.fard { if let t = today[p], t <= now { last = (p, t) } }
        if let last { return last }
        if let y = yesterdayIsha { return (.isha, y) }
        return nil
    }

    /// "Fuel" for the idle line: full after you pray, draining toward the next prayer.
    /// With the prayer screen on, it stays empty after the adhan until you confirm you prayed.
    var fuel: Double {
        if settings.lockEnabled, let cur = current {
            let since = now.timeIntervalSince(cur.time)
            if since >= 0, since < 3 * 3600, !PrayerLog.prayed(on: cur.time, tz: tz).contains(cur.prayer) { return 0.04 }
        }
        return max(0.04, 1 - progress)
    }

    /// 0…1 progress from the previous prayer to the next one.
    var progress: Double {
        guard let cur = current else { return 0 }
        let total = next.time.timeIntervalSince(cur.time)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(cur.time) / total))
    }

    var isFriday: Bool { calendar.component(.weekday, from: now) == 6 }

    var fastingToday: [FastingDay] { Fasting.reasons(for: now, hijriAdjust: settings.hijriAdjust) }
    var fastingTomorrow: [FastingDay] {
        Fasting.reasons(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now, hijriAdjust: settings.hijriAdjust)
    }

    // MARK: events

    private func tick() {
        now = Date()
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        if "\(c.year!)-\(c.month!)-\(c.day!)" != dayKey { recompute() }

        let lockWindow = TimeInterval(max(1, settings.lockMinutes) * 60)
        for p in Prayer.fard {
            guard let t = today[p] else { continue }
            if now >= t, now < t.addingTimeInterval(lockWindow), mark("adhan-\(p.rawValue)") {
                onAdhan?(p, t)
            }
            let pre = TimeInterval(settings.preAlertMinutes * 60)
            if pre > 0, now >= t.addingTimeInterval(-pre), now < t.addingTimeInterval(-30), mark("pre-\(p.rawValue)") {
                onPreAlert?(p, t)
            }
        }

        // Morning adhkar after Fajr (once the lock is over), evening adhkar after Asr.
        if settings.adhkarReminders {
            let delay = TimeInterval((settings.lockMinutes + 5) * 60)
            if let f = today[.fajr], let d = today[.dhuhr], now >= f.addingTimeInterval(delay), now < d,
               !MorningEvening.isDone(.morning), mark("adhkar-morning") { onAdhkar?(.morning) }
            if let a = today[.asr], let m = today[.maghrib], now >= a.addingTimeInterval(delay), now < m,
               !MorningEvening.isDone(.evening), mark("adhkar-evening") { onAdhkar?(.evening) }
        }

        // Daily Quran portion, after the chosen prayer.
        if settings.wirdEnabled, let p = Prayer(rawValue: settings.wirdAfter), let t = today[p],
           now >= t.addingTimeInterval(TimeInterval((settings.lockMinutes + 5) * 60)),
           now < t.addingTimeInterval(6 * 3600) {
            QuranWird.shared.refresh()
            if !QuranWird.shared.doneToday, mark("wird") { onWird?() }
        }

        // Duha: halfway between sunrise and Dhuhr, until 15 min before Dhuhr.
        if settings.duhaReminder, let t = Nafl.time(.duha, today: today, tomorrow: tomorrow), let dh = today[.dhuhr],
           now >= t, now < dh.addingTimeInterval(-15 * 60), !Nafl.did(.duha, on: now), mark("duha") {
            onNafl?(.duha)
        }
        // Qiyam: from the start of the night's last third until 10 min before Fajr (handles after-midnight).
        if settings.qiyamReminder, let w = qiyamWindow(), now >= w.start, now < w.end.addingTimeInterval(-10 * 60),
           mark("qiyam") {
            onNafl?(.qiyam)
        }

        // Sadaqa reminder after Dhuhr (daily or Fridays).
        if settings.sadaqaReminder != "off", let dh = today[.dhuhr],
           settings.sadaqaReminder == "daily" || isFriday,
           now >= dh.addingTimeInterval(TimeInterval((settings.lockMinutes + 25) * 60)),
           now < dh.addingTimeInterval(5 * 3600),
           !SadaqaLog.shared.gave(), mark("sadaqa") { onSadaqa?() }

        // Family ties — checked every 20 s, not every second.
        if Int(now.timeIntervalSince1970) % 20 == 0 { checkRahim() }

        // Fasting reminder: the evening before, 20 minutes after Maghrib.
        if settings.fastingReminders, let m = today[.maghrib], now >= m.addingTimeInterval(20 * 60),
           let isha = today[.isha], now < isha.addingTimeInterval(3 * 3600) {
            let reasons = fastingTomorrow
            if !reasons.isEmpty, mark("fast") { onFasting?(reasons) }
        }

        // Periodic dhikr / Palestine reminders, kept away from prayer times.
        if settings.reminderMinutes > 0,
           now.timeIntervalSince(lastReminder) >= TimeInterval(settings.reminderMinutes * 60),
           settings.alwaysShowDhikr || !nearPrayer {
            let r = makeReminder()
            onReminder?(r.0, r.1)
        }
    }

    private func checkRahim() {
        let lock = TimeInterval(settings.lockMinutes * 60)
        // One person per evening (after Asr, until a few hours after Isha).
        if settings.rahimReminders, let a = today[.asr], let isha = today[.isha],
           now >= a.addingTimeInterval(lock + 30 * 60), now < isha.addingTimeInterval(3 * 3600),
           let r = RahimStore.shared.due(now: now), mark("rahim-\(r.id.uuidString)-\(r.snoozes)") {
            onRahim?(r.id, RahimStore.rotator.pick(RahimStore.hadith))
        }
        // Friday, after Jumu'ah.
        if settings.rahimWeekly, isFriday, let dh = today[.dhuhr],
           now >= dh.addingTimeInterval(lock + 60 * 60), now < dh.addingTimeInterval(6 * 3600), mark("rahim-weekly") {
            onRahim?(nil, RahimStore.rotator.pick(RahimStore.hadith))
        }
        // First of Ramadan and the two Eids, mid-morning.
        if settings.rahimSeasons, let sr = today[.sunrise], let m = today[.maghrib],
           now >= sr.addingTimeInterval(90 * 60), now < m {
            let h = Hijri.components(now, adjust: settings.hijriAdjust)
            var line: Msg?
            if h.month == 9 && h.day == 1 { line = Msg(tr("رمضان كريم… ابعت تهنئة لأهلك، وكلّم الكبار فيهم"), tr("صلة الرحم في رمضان أجرها مضاعف بإذن الله")) }
            if h.month == 10 && h.day == 1 { line = Msg(tr("عيد مبارك… كلّم أهلك وعيّد عليهم، وابدأ بالكبار"), tr("تقبّل الله منا ومنكم")) }
            if h.month == 12 && h.day == 10 { line = Msg(tr("عيد أضحى مبارك… عيّد على أهلك وصِل اللي بعيد عنك"), tr("تقبّل الله منا ومنكم")) }
            if let line, mark("rahim-season") { onRahim?(nil, line) }
        }
    }

    /// The current night's last third: (start, Fajr).
    func qiyamWindow() -> (start: Date, end: Date)? {
        if let f = today[.fajr], now < f, let m = today[.maghrib] {
            let ym = m.addingTimeInterval(-86400)          // last night's Maghrib (close enough)
            return (ym.addingTimeInterval(f.timeIntervalSince(ym) * 2 / 3), f)
        }
        if let m = today[.maghrib], let f = tomorrow[.fajr] {
            return (m.addingTimeInterval(f.timeIntervalSince(m) * 2 / 3), f)
        }
        return nil
    }

    /// Next dhikr in the rotation (every third one is for Palestine when enabled).
    func makeReminder() -> (Msg, Bool) {
        lastReminder = Date()
        reminderCount += 1
        let slot = reminderCount % 10
        if (slot == 2 || slot == 7) && settings.palestineReminders {
            return (MessagePicker.palestineDuaRotator.pick(Palestine.duas), true)
        }
        if slot == 4 { return (MessagePicker.ummahRotator.pick(Ummah.duas), false) }
        // One idle line in ten is about Ramadan when it's near (or here).
        if slot == 6 {
            if let d = ramadanDay { return (Msg(trf("رمضان كريم · اليوم %@ من رمضان", AR.num(d))), false) }
            if (1...120).contains(ramadanDays) { return (Msg(trf("رمضان بعد %@ يوم… جهّزت خطتك؟", AR.num(ramadanDays))), false) }
        }
        if slot == 9 || slot == 2 || slot == 7 { return (MessagePicker.duaRotator.pick(Adhkar.duas), false) }
        return (MessagePicker.dhikrRotator.pick(Adhkar.dhikr), false)
    }

    private var nearPrayer: Bool {
        for p in Prayer.fard {
            guard let t = today[p] else { continue }
            let d = now.timeIntervalSince(t)
            if d > -15 * 60 && d < TimeInterval(settings.lockMinutes * 60 + 5 * 60) { return true }
        }
        return false
    }

    /// Returns true the first time a key is marked today.
    private func mark(_ name: String) -> Bool {
        let key = "\(name)@\(dayKey)"
        guard !fired.contains(key) else { return false }
        fired.insert(key)
        persistFired()
        return true
    }

    private func persistFired() { UserDefaults.standard.set(Array(fired), forKey: "fired") }
}
