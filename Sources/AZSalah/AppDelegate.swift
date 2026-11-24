import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let settings = AppSettings.shared
    lazy var engine = PrayerEngine(settings: settings)
    lazy var notch = NotchController(engine: engine, settings: settings)
    let lock = LockController()
    lazy var settingsWindow = SettingsWindowController(settings: settings, engine: engine)
    private var statusItem: NSStatusItem?
    private var pending: (prayer: Prayer, time: Date)?
    private var snoozesUsed: [Prayer: Int] = [:]
    private var meetingTimer: Timer?
    private var displayObserver: Any?
    private var ambientObserver: Any?
    private var floatObserver: Any?
    private var scaleObserver: Any?
    private var idleObserver: Any?

    /// A prayer skipped with "emergency": reminded in the notch, locked again once, and once more before its time ends.
    private struct Owed {
        let prayer: Prayer
        let adhan: Date
        let ends: Date
        var relockAt: Date
        var relockDone = false
        var finalDone = false
    }
    private var owed: Owed? { didSet { updateOwedUI() } }
    private var owedTimer: Timer?
    let ramadanWindow = RamadanWindowController()
    let adhkarWindow = AdhkarWindowController()
    private var ramadanTimer: Timer?
    private var breathWork: DispatchWorkItem?

    /// After an update the old copy may still be running (e.g. the app was replaced in /Applications while open).
    /// The copy launched last wins: ask the others to quit, and force them if they don't within 2 seconds.
    private func closeOtherCopies() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter { $0.processIdentifier != me }
        guard !others.isEmpty else { return }
        LockLog.write("closing \(others.count) older copy/copies")
        others.forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            others.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
        }
    }

    private func refreshAmbient() {
        if owed != nil { updateOwedUI(); return }
        if settings.alwaysShowDhikr && settings.reminderMinutes > 0 {
            let r = engine.makeReminder()
            notch.ambient = .init(msg: r.0, palestine: r.1)
        } else {
            notch.ambient = nil
        }
    }

    static let meetingApps: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams", "com.microsoft.teams2", "com.apple.FaceTime",
        "com.cisco.webexmeetingsapp", "com.cisco.webex.meetings", "com.webex.meetingmanager",
        "com.tinyspeck.slackmacgap.huddle", "com.skype.skype", "com.hnc.Discord",
    ]

    func applicationDidFinishLaunching(_ note: Notification) {
        closeOtherCopies()
        wire()
        notch.start()
        idleObserver = settings.$idleLevel.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.notch.updateWings() }
        }
        scaleObserver = settings.$islandScale.dropFirst()
            .debounce(for: .milliseconds(60), scheduler: RunLoop.main).sink { [weak self] _ in
                DispatchQueue.main.async { self?.notch.rebuild() }
            }
        floatObserver = settings.$islandFloating.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            DispatchQueue.main.async { self?.notch.rebuild() }
        }
        displayObserver = settings.$displayMode.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            DispatchQueue.main.async { self?.notch.rebuild() }
        }
        ambientObserver = settings.$alwaysShowDhikr.combineLatest(settings.$reminderMinutes).dropFirst()
            .receive(on: RunLoop.main).sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshAmbient() }
            }
        refreshAmbient()
        setupStatusItem()
        engine.start()
        UpdateChecker.shared.start()
        let rt = Timer(timeInterval: 15 * 60, repeats: true) { [weak self] _ in self?.checkRamadan(); self?.checkZakat() }
        RunLoop.main.add(rt, forMode: .common)
        ramadanTimer = rt
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in self?.checkRamadan() }
        if CommandLine.arguments.contains("--test-lock") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.testLock() }
        }
        if CommandLine.arguments.contains("--demo") { runDemo() }
        if !settings.locationConfirmed || !settings.timeZoneMatches {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.settingsWindow.show() }
        }
        if !UserDefaults.standard.bool(forKey: "onboarded") {
            UserDefaults.standard.set(true, forKey: "onboarded")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.settingsWindow.show() }
        }
    }

    private func wire() {
        engine.onAdhan = { [weak self] p, t in self?.adhan(p, t) }
        engine.onPreAlert = { [weak self] p, t in
            self?.notch.show(.pre(p, t), for: 14)
            NSSound(named: "Tink")?.play()
        }
        engine.onReminder = { [weak self] msg, pal in
            guard let self else { return }
            if self.settings.alwaysShowDhikr {
                guard self.owed == nil else { return } // the "not prayed yet" line stays put
                self.notch.ambient = .init(msg: msg, palestine: pal)
                return
            }
            guard !self.lock.isShowing, self.owed == nil else { return }
            // "Breathing": the notch grows with the dhikr for a few seconds, then folds back to its own size.
            self.breathWork?.cancel()
            self.notch.ambient = .init(msg: msg, palestine: pal)
            let w = DispatchWorkItem { [weak self] in
                guard let self, self.owed == nil, !self.settings.alwaysShowDhikr else { return }
                self.notch.ambient = nil
            }
            self.breathWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(max(4, self.settings.peekSeconds)), execute: w)
        }
        engine.onFasting = { [weak self] reasons in
            guard let self else { return }
            let detail = reasons.first.map { r in r.source.map { "«\(r.detail)» — \($0)" } ?? r.detail } ?? ""
            self.notch.show(.fasting(reasons.map(\.title), detail), for: 20)
        }
        notch.onLockNow = { [weak self] p in
            guard let self else { return }
            let t = self.pending?.time ?? Date()
            self.pending = nil
            self.showLock(p, t, duration: self.remaining(from: t))
        }
        notch.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        notch.onConfirmOwed = { [weak self] in self?.confirmOwed() }
        notch.onOpenRamadan = { [weak self] in self?.ramadanWindow.show() }
        notch.onOpenAdhkar = { [weak self] k in self?.adhkarWindow.show(k) }
        engine.onAdhkar = { [weak self] k in
            self?.whenUnlocked {
                guard let self, !MorningEvening.isDone(k) else { return }
                let m = MorningEvening.rotator.pick(MorningEvening.motivation[k] ?? [])
                self.notch.show(.adhkar(k, m), for: 40)
            }
        }
        UpdateChecker.shared.onAvailable = { [weak self] r in
            self?.whenUnlocked { self?.notch.show(.update(r.version, r.notes), for: 30) }
        }
        engine.onSadaqa = { [weak self] in
            self?.whenUnlocked {
                guard let self, !SadaqaLog.shared.gave() else { return }
                SadaqaFlow.shared.reset()
                self.notch.show(.sadaqa(SadaqaLog.rotator.pick(SadaqaLog.motivation)), for: 40)
            }
        }
        engine.onRahim = { [weak self] id, msg in
            self?.whenUnlocked {
                guard let self else { return }
                RahimFlow.shared.stage = .main
                let idea = RahimStore.ideaRotator.pick(RahimStore.ideas.map { Msg($0) }).text
                LockLog.write("rahim reminder")
                self.notch.show(.rahim(id, msg, idea), for: 10 * 60)
            }
        }
        engine.onNafl = { [weak self] k in
            self?.whenUnlocked {
                guard let self, !Nafl.did(k, on: Date()) else { return }
                let m = Nafl.rotator.pick(Nafl.motivation[k] ?? [])
                LockLog.write("nafl reminder: \(k.rawValue)")
                // Stays until answered (up to 20 min) — a reminder, not a lock.
                self.notch.show(.nafl(k, m), for: 20 * 60)
            }
        }
        notch.onNaflCommit = { [weak self] k in
            guard let self else { return }
            self.notch.show(.info(tr("يلا… ربنا يتقبّل منك"), tr("نيّتك اتسجلت، هنسألك بعد ربع ساعة")), for: 6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 15 * 60) { [weak self] in
                self?.whenUnlocked {
                    guard let self, !Nafl.did(k, on: Date()) else { return }
                    self.notch.show(.naflCheck(k), for: 15 * 60)
                }
            }
        }
        engine.onWird = { [weak self] in
            self?.whenUnlocked {
                guard let self, !QuranWird.shared.doneToday else { return }
                self.notch.show(.wird(QuranWird.rotator.pick(QuranWird.motivation)), for: 40)
            }
        }
        settingsWindow.onTestLock = { [weak self] in self?.testLock() }
        lock.onEnd = { [weak self] reason in self?.lockEnded(reason) }
    }

    // MARK: adhan flow

    private func adhan(_ p: Prayer, _ t: Date) {
        LockLog.write("adhan event: \(p.rawValue) at \(t) tzMatch=\(settings.timeZoneMatches) confirmed=\(settings.locationConfirmed)")
        // Never lock on times that may belong to another place.
        guard settings.timeZoneMatches, settings.locationConfirmed else {
            notch.show(.info(tr("مواعيد الصلاة محتاجة تتظبط"),
                             settings.timeZoneMatches ? tr("أكّد مدينتك من الإعدادات… مش هنقفل الشاشة لحد كده")
                                                      : tr("المدينة المختارة توقيتها مختلف عن جهازك. اختار مدينتك من الإعدادات")), for: 30)
            return
        }
        SoundPlayer.play(settings, prayer: p)
        snoozesUsed[p] = 0
        guard settings.locks(p) else {
            notch.show(.info(trf("حان الآن موعد صلاة %@", p.arabic(friday: engine.isFriday)),
                                   MessagePicker.adhanMessage(for: p, friday: engine.isFriday).msg.text), for: 30)
            return
        }
        if settings.deferInMeetings && inMeeting {
            pending = (p, t)
            notch.show(.deferred(p), for: nil)
            watchMeeting()
            return
        }
        showLock(p, t, duration: remaining(from: t))
    }

    private func remaining(from t: Date) -> TimeInterval {
        let end = t.addingTimeInterval(TimeInterval(settings.lockMinutes * 60))
        return max(90, end.timeIntervalSinceNow)
    }

    private func showLock(_ p: Prayer, _ t: Date, duration: TimeInterval, note: String? = nil, allowEmergency: Bool = true) {
        // Last safety net: only inside this prayer's own time, and only for a city that matches this Mac.
        let now = Date()
        guard settings.timeZoneMatches, settings.locationConfirmed,
              now >= t.addingTimeInterval(-60), now < prayerEnds(p, adhan: t) else {
            LockLog.write("lock blocked: prayer=\(p.rawValue) adhan=\(t) now=\(now)")
            return
        }
        notch.dismissAlert()
        let used = snoozesUsed[p] ?? 0
        lock.show(prayer: p, adhanTime: t, duration: duration, settings: settings,
                  snoozesLeft: max(0, settings.maxSnoozes - used), friday: engine.isFriday && p == .dhuhr,
                  note: note, allowEmergency: allowEmergency)
    }

    // MARK: follow-up after an emergency

    /// When a prayer's time runs out.
    private func prayerEnds(_ p: Prayer, adhan: Date) -> Date {
        let t = engine.today, tm = engine.tomorrow
        let end: Date?
        switch p {
        case .fajr: end = t[.sunrise]
        case .dhuhr: end = t[.asr]
        case .asr: end = t[.maghrib]
        case .maghrib: end = t[.isha]
        case .isha: end = tm[.fajr]
        case .sunrise: end = nil
        }
        if let end, end > adhan { return end }
        return adhan.addingTimeInterval(2 * 3600)
    }

    private func startOwed(_ p: Prayer, _ t: Date) {
        owed = Owed(prayer: p, adhan: t, ends: prayerEnds(p, adhan: t),
                    relockAt: Date().addingTimeInterval(TimeInterval(settings.followUpMinutes * 60)))
        owedTimer?.invalidate()
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in self?.checkOwed() }
        RunLoop.main.add(timer, forMode: .common)
        owedTimer = timer
    }

    private func checkOwed() {
        guard var o = owed else { owedTimer?.invalidate(); owedTimer = nil; return }
        let now = Date()
        if now >= o.ends { owed = nil; return }
        guard !lock.isShowing else { return }
        let name = o.prayer.arabic(friday: engine.isFriday && o.prayer == .dhuhr)
        let lastCall = o.ends.addingTimeInterval(-15 * 60)
        let duration = min(TimeInterval(settings.lockMinutes * 60), max(90, o.ends.timeIntervalSince(now)))
        if !o.finalDone && now >= lastCall {
            o.finalDone = true; o.relockDone = true; owed = o
            SoundPlayer.play(settings, prayer: o.prayer)
            showLock(o.prayer, o.adhan, duration: duration, note: trf("وقت %@ قرّب يخلص", name), allowEmergency: false)
        } else if !o.relockDone && now >= o.relockAt {
            o.relockDone = true; owed = o
            SoundPlayer.play(settings, prayer: o.prayer)
            showLock(o.prayer, o.adhan, duration: duration, note: trf("لسه ما صلّيتش %@", name), allowEmergency: false)
        }
    }

    private func updateOwedUI() {
        guard let o = owed else {
            notch.owedPrayer = nil
            if settings.alwaysShowDhikr && settings.reminderMinutes > 0 {
                let r = engine.makeReminder()
                notch.ambient = .init(msg: r.0, palestine: r.1)
            } else {
                notch.ambient = nil
            }
            return
        }
        let name = o.prayer.arabic(friday: engine.isFriday && o.prayer == .dhuhr)
        notch.owedPrayer = o.prayer
        notch.ambient = .init(msg: Msg(trf("لسه ما صلّيتش %@ — الوقت لحد %@", name, AR.time(o.ends, tz: engine.tz))),
                              palestine: false, owed: true)
    }

    /// Runs `f` now, or as soon as the prayer screen is gone (checks every 30 s, gives up after 2 h).
    private func whenUnlocked(_ f: @escaping () -> Void, tries: Int = 0) {
        if !lock.isShowing { f(); return }
        guard tries < 240 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in self?.whenUnlocked(f, tries: tries + 1) }
    }

    // MARK: Zakat due reminder

    /// A week before the zakat date and on the day itself (once each).
    private func checkZakat() {
        guard !lock.isShowing, Calendar.current.component(.hour, from: Date()) >= 11,
              let n = ZakatStore.shared.daysUntilDue(adjust: settings.hijriAdjust), n == 7 || n == 0 else { return }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let key = "zakatNotice.\(c.year!)-\(c.month!)-\(c.day!)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let z = ZakatStore.shared
        let amount = z.reachesNisab ? trf("زكاتك تقريبًا %@ %@", ZakatStore.money(z.zakat), z.currency) : tr("احسبها من قسم «العطاء» في النوتش")
        notch.show(.zakat(n == 0 ? tr("ميعاد زكاتك النهارده") : tr("زكاتك بعد أسبوع إن شاء الله"),
                          trf("«وأقيموا الصلاة وآتوا الزكاة» · %@", amount)), for: 40)
    }

    // MARK: Ramadan plan reminders

    /// Once a day: a countdown before Ramadan (on a few milestone days), and a goal from your plan during it.
    private func checkRamadan() {
        guard !lock.isShowing else { return }
        let cal = Calendar.current
        let now = Date()
        guard cal.component(.hour, from: now) >= 10 else { return }
        let c = cal.dateComponents([.year, .month, .day], from: now)
        let key = "ramadanNotice.\(c.year!)-\(c.month!)-\(c.day!)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let adjust = settings.hijriAdjust
        let plan = RamadanPlan.shared
        plan.reload()
        var alert: NotchModel.Alert?
        if let day = RamadanPlan.dayOfRamadan(now, adjust: adjust) {
            let goal = plan.pending.randomElement()?.text
            switch day {
            case 1:
                let list = plan.goals.prefix(2).map(\.text).joined(separator: " · ")
                alert = .ramadan(tr("رمضان كريم… أهلاً رمضان"),
                                 list.isEmpty ? tr("اكتب خطتك دلوقتي وابدأ من النهارده") : trf("دي خطتك اللي كتبتها: %@", list))
            case 21:
                alert = .ramadan(tr("العشر الأواخر بدأت"), tr("قيام وليلة القدر… راجع خطتك وكمّل اللي فاضل"))
            default:
                alert = .ramadan(trf("رمضان · اليوم %@", AR.num(day)),
                                 goal.map { trf("خطتك النهارده: %@", $0) } ?? tr("خلّصت خطتك؟ ما شاء الله… زوّد هدف جديد"))
            }
        } else {
            let days = RamadanPlan.daysUntil(from: now, adjust: adjust)
            if [30, 20, 15, 10, 7, 5, 3, 2, 1].contains(days) {
                alert = .ramadan(trf("رمضان بعد %@ يوم إن شاء الله", AR.num(days)),
                                 plan.goals.isEmpty ? tr("جهّزت خطتك؟ اكتبها من دلوقتي") : trf("عندك %@ أهداف مكتوبة… جاهز؟", AR.num(plan.goals.count)))
            }
        }
        guard let alert else { return }
        UserDefaults.standard.set(true, forKey: key)
        notch.show(alert, for: 25)
    }

    /// "صلّيت" from the notch: straight to the testimony.
    private func confirmOwed() {
        guard let o = owed, !lock.isShowing else { return }
        showLock(o.prayer, o.adhan, duration: 120, note: tr("الحمد لله"), allowEmergency: false)
        lock.model.doneAfter = 0
        lock.model.stage = .proof
    }

    private func lockEnded(_ reason: LockEnd) {
        SoundPlayer.stop()
        let p = lock.model.prayer, t = lock.model.adhanTime
        LockLog.write("lock ended: \(reason) prayer=\(p.rawValue) test=\(lock.model.isTest)")
        // A test run from "جرّب شاشة الصلاة" must never schedule a real lock
        // (snoozing or "emergency" in a test used to bring the next prayer's screen back minutes later).
        if lock.model.isTest {
            notch.show(.info(tr("خلصت التجربة"), tr("شاشة الصلاة هتظهر بجد في وقت الأذان بإذن الله")), for: 5)
            return
        }
        switch reason {
        case .snoozed:
            snoozesUsed[p, default: 0] += 1
            let mins = settings.snoozeMinutes
            notch.show(.info(trf("اتأجّلت %@ دقايق", AR.num(mins)), trf("هنفكّرك بصلاة %@ تاني", p.arabic(friday: engine.isFriday))), for: 6)
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(mins * 60)) { [weak self] in
                guard let self, !self.lock.isShowing else { return }
                self.showLock(p, t, duration: TimeInterval(max(3, self.settings.lockMinutes / 2) * 60))
            }
        case .prayed:
            if owed?.prayer == p { owed = nil }
            engine.objectWillChange.send()      // refill the fuel line right away
            notch.show(.info(tr("تقبّل الله منك"), tr("اللهم اجعلنا من المقيمين الصلاة")), for: 6)
        case .emergency:
            startOwed(p, t)
            notch.show(.info(tr("ربنا ييسّر"), trf("هنفكّرك بصلاة %@ تاني بعد %@ دقيقة", p.arabic(friday: engine.isFriday), AR.num(settings.followUpMinutes))), for: 8)
        case .timeUp:
            break
        }
    }

    // MARK: meetings

    private var inMeeting: Bool {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        if Self.meetingApps.contains(id) { return true }
        // Google Meet in a browser: check the front window title.
        let browsers: Set<String> = ["com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "com.microsoft.edgemac", "com.brave.Browser"]
        if browsers.contains(id), let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
                if let name = w[kCGWindowName as String] as? String, name.contains("Meet -") || name.hasPrefix("Meet ") { return true }
            }
        }
        return false
    }

    private func watchMeeting() {
        meetingTimer?.invalidate()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] tm in
            guard let self, let pend = self.pending else { tm.invalidate(); return }
            let windowEnd = pend.time.addingTimeInterval(TimeInterval(self.settings.lockMinutes * 60 + 60 * 60))
            if Date() > windowEnd { self.pending = nil; self.notch.dismissAlert(); tm.invalidate(); return }
            if !self.inMeeting {
                tm.invalidate()
                self.pending = nil
                self.showLock(pend.prayer, pend.time, duration: TimeInterval(self.settings.lockMinutes * 60))
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        meetingTimer = timer
    }

    // MARK: test / demo

    func testLock() {
        let p = engine.next.prayer
        lock.show(prayer: p, adhanTime: Date(), duration: 30, settings: settings, snoozesLeft: 1, friday: false)
        lock.model.doneAfter = 5
        lock.model.isTest = true
        LockLog.write("test lock (from settings/menu)")
    }

    private func runDemo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.notch.show(.fasting(self.engine.fastingTomorrow.map(\.title).isEmpty ? [tr("يوم الخميس")] : self.engine.fastingTomorrow.map(\.title),
                                           tr("«تُعرض الأعمال يوم الاثنين والخميس» — رواه الترمذي")), for: 6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            self.notch.show(.peek(Palestine.items[1], palestine: true), for: 8)
        }
    }

    // MARK: menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = item.button {
            let img = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: "AZ Itqan")
            img?.isTemplate = true
            b.image = img
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let n = engine.next
        let head = NSMenuItem(title: trf("%@ بعد %@", n.prayer.arabic(friday: engine.isFriday), AR.countdown(n.time.timeIntervalSinceNow)), action: nil, keyEquivalent: "")
        head.isEnabled = false
        menu.addItem(head)
        for p in Prayer.allCases {
            let t = engine.today[p].map { AR.time($0, tz: engine.tz, ampm: true) } ?? "—"
            let i = NSMenuItem(title: "\(p.arabic(friday: engine.isFriday))    \(t)", action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(i)
        }
        if let f = engine.fastingTomorrow.first {
            let i = NSMenuItem(title: trf("بكرة إن شاء الله: %@", f.title), action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(.separator()); menu.addItem(i)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: tr("أذكار الصباح"), action: #selector(openMorning), keyEquivalent: "").target = self
        menu.addItem(withTitle: tr("أذكار المساء"), action: #selector(openEvening), keyEquivalent: "").target = self
        menu.addItem(withTitle: tr("خطتي لرمضان…"), action: #selector(openRamadan), keyEquivalent: "").target = self
        if let r = UpdateChecker.shared.latest {
            menu.addItem(withTitle: trf("حمّل التحديث %@…", r.version), action: #selector(downloadUpdate), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: tr("الإعدادات…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: tr("جرّب شاشة الصلاة"), action: #selector(testLockAction), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: tr("خروج من AZ Itqan"), action: #selector(quit), keyEquivalent: "q").target = self
    }

    @objc private func openSettings() { settingsWindow.show() }
    @objc private func openRamadan() { ramadanWindow.show() }
    @objc private func downloadUpdate() { UpdateChecker.shared.download() }
    @objc private func openMorning() { adhkarWindow.show(.morning) }
    @objc private func openEvening() { adhkarWindow.show(.evening) }
    @objc private func testLockAction() { testLock() }
    @objc private func quit() { NSApp.terminate(nil) }
}
