import SwiftUI
import AppKit

/// Offscreen renders of each UI state, for design review.
@MainActor enum Snapshots {
    /// App icon from the official vector mark (white letters, lime slash) on the brand gradient tile.
    static func icon(to url: URL) {
        let tile = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x23308A), Color(hex: 0x061230)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(RadialGradient(colors: [AZBrand.blue.opacity(0.55), .clear], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 470))
            AZMark(letterColor: .white, slashColor: AZ.lime).frame(width: 540)
        }
        .frame(width: 824, height: 824)
        .frame(width: 1024, height: 1024)
        let r = ImageRenderer(content: tile)
        r.scale = 1
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
            print("wrote icon")
        }
    }


    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = AppSettings.shared
        let engine = PrayerEngine(settings: settings)
        let notch = NotchModel()
        notch.notchWidth = 185; notch.notchHeight = 32

        func save<V: View>(_ name: String, _ view: V, _ size: CGSize) {
            let r = ImageRenderer(content: view.frame(width: size.width, height: size.height)
                .environment(\.layoutDirection, Lang.dir))
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                print("failed \(name)"); return
            }
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
            print("wrote \(name).png")
        }

        let canvas = CGSize(width: 640, height: 360)
        func notchScene() -> some View {
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: 0x8DA2C8), Color(hex: 0xC9B8D9)], startPoint: .top, endPoint: .bottom)
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: 32)
                NotchRootView(model: notch, engine: engine)
                // The real camera housing, so previews read like the actual screen.
                if notch.hasNotch {
                    UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9)
                        .fill(Color(hex: 0x1A1A1A))
                        .overlay(Circle().fill(Color(hex: 0x2B3550)).frame(width: 6, height: 6))
                        .frame(width: notch.notchWidth, height: notch.notchHeight)
                }
            }
        }
        save("1-notch-compact", notchScene(), canvas)
        for lvl in 0...3 {
            notch.idleLevel = lvl
            save("1-idle-level-\(lvl)", notchScene(), CGSize(width: 640, height: 80))
        }
        notch.wings = true
        notch.ambient = .init(msg: Adhkar.dhikr[12], palestine: false)
        save("1b-notch-ambient-short", notchScene(), CGSize(width: 640, height: 110))
        notch.ambient = .init(msg: Adhkar.dhikr[0], palestine: false)
        save("1b-notch-ambient", notchScene(), CGSize(width: 640, height: 110))
        notch.ambient = .init(msg: Palestine.duas[1], palestine: true)
        save("1b-notch-ambient-palestine2", notchScene(), CGSize(width: 640, height: 110))
        notch.ambient = .init(msg: Ummah.duas[0], palestine: false)
        save("1b-notch-ambient-ummah", notchScene(), CGSize(width: 640, height: 110))
        notch.ambient = .init(msg: Palestine.duas[0], palestine: true)
        save("1b-notch-ambient-palestine", notchScene(), CGSize(width: 640, height: 110))
        notch.ambient = .init(msg: Msg("رمضان بعد ٧٧ يوم… جهّزت خطتك؟"), palestine: false)
        save("1e-notch-ramadan-line", notchScene(), CGSize(width: 640, height: 110))
        notch.ambient = .init(msg: Msg("لسه ما صلّيتش العصر — الوقت لحد ٤:٥٦"), palestine: false, owed: true)
        save("1d-notch-owed", notchScene(), CGSize(width: 640, height: 110))
        notch.ambient = nil
        notch.owedPrayer = .asr
        notch.expanded = true
        save("2b-notch-expanded-owed", notchScene(), canvas)
        notch.expanded = false
        notch.owedPrayer = nil
        notch.hasNotch = false
        notch.ambient = .init(msg: Adhkar.dhikr[0], palestine: false)
        save("1c-external-screen", notchScene(), CGSize(width: 640, height: 110))
        notch.hasNotch = true
        notch.ambient = nil
        notch.expanded = true
        save("2-notch-expanded", notchScene(), CGSize(width: 640, height: 470))
        AdhkarSession.shared.start(.morning)
        AdhkarSession.shared.counts = [0: 1, 1: 3]
        AdhkarSession.shared.index = 2
        notch.reader = .morning
        save("2c-notch-adhkar-reader", notchScene(), CGSize(width: 640, height: 400))
        AdhkarSession.shared.index = 0
        save("2d-notch-adhkar-kursi", notchScene(), CGSize(width: 640, height: 400))
        notch.reader = nil
        // sample data for the report / giving previews (CLI defaults only)
        let tzS = settings.location.timeZone
        for back in 0..<30 {
            let d = Calendar.current.date(byAdding: .day, value: -back, to: Date())!
            for p in Prayer.fard where (back * 7 + p.hashValue) % 9 != 0 { PrayerLog.mark(p, on: d, tz: tzS, .prayed) }
            if back % 2 == 0 { UserDefaults.standard.set(true, forKey: "sadaqa.\(Calendar.current.component(.year, from: d))-\(Calendar.current.component(.month, from: d))-\(Calendar.current.component(.day, from: d))") }
        }
        let z = ZakatStore.shared
        z.cash = 250000; z.gold24 = 20; z.gold21 = 35; z.goldPrice = 5200; z.receivables = 10000; z.debts = 15000
        z.dueMonth = 9; z.dueDay = 1
        notch.tab = 1
        save("2e-notch-report", notchScene(), CGSize(width: 640, height: 400))
        notch.tab = 2
        save("2f-notch-giving", notchScene(), CGSize(width: 640, height: 400))
        notch.tab = 0
        notch.expanded = false
        notch.floating = true; notch.notchWidth = 22; notch.notchHeight = 30; notch.hasNotch = false
        save("1f-floating-compact", notchScene(), CGSize(width: 640, height: 80))
        notch.ambient = .init(msg: Adhkar.dhikr[0], palestine: false)
        save("1g-floating-ambient", notchScene(), CGSize(width: 640, height: 110))
        notch.scale = 1.35
        save("1h-floating-scaled", notchScene(), CGSize(width: 640, height: 150))
        notch.ambient = nil
        notch.expanded = true
        save("1i-floating-scaled-expanded", notchScene(), CGSize(width: 900, height: 560))
        notch.expanded = false
        notch.scale = 1
        notch.ambient = nil
        notch.floating = false; notch.notchWidth = 185; notch.notchHeight = 32; notch.hasNotch = true
        notch.expanded = true
        notch.expanded = false
        notch.alert = .pre(.asr, Date().addingTimeInterval(600))
        save("3-notch-pre-alert", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .fasting(["يوم الخميس", "الأيام البيض"], "«تُعرض الأعمال يوم الاثنين والخميس» — رواه الترمذي")
        save("4-notch-fasting", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .peek(Adhkar.reminders[0], palestine: false)
        save("5-notch-peek", notchScene(), CGSize(width: 640, height: 160))

        let lock = LockModel()
        let pick = MessagePicker.adhanMessage(for: .asr, friday: false)
        lock.prayer = .asr; lock.adhanTime = Date(); lock.shownAt = Date().addingTimeInterval(-200)
        lock.endsAt = Date().addingTimeInterval(400); lock.headline = pick.headline; lock.message = pick.msg
        lock.palestine = Palestine.items[1]; lock.snoozesLeft = 2; lock.appear = true
        lock.tz = settings.location.timeZone
        save("6-lock-screen", LockView(model: lock, primary: true, scale: 0.9) { _ in }, CGSize(width: 1512, height: 982))
        lock.showBuddy = true
        save("6e-lock-buddy", LockView(model: lock, primary: true, scale: 0.9) { _ in }, CGSize(width: 1512, height: 982))
        lock.showBuddy = false
        lock.snoozeWindowEnd = Date().addingTimeInterval(400)
        lock.snoozesLeft = 1
        lock.snoozeLine = SnoozeMotivation.lines[0]; lock.snoozeHadith = SnoozeMotivation.hadith[0]
        lock.snoozeUnlockAt = Date().addingTimeInterval(6)
        lock.stage = .snooze
        save("6b-lock-snooze", LockView(model: lock, primary: true, scale: 0.9) { _ in }, CGSize(width: 1512, height: 982))
        lock.stage = .main
        lock.note = "وقت العصر قرّب يخلص"; lock.allowEmergency = false; lock.snoozesLeft = 0
        save("6d-lock-last-call", LockView(model: lock, primary: true, scale: 0.9) { _ in }, CGSize(width: 1512, height: 982))
        lock.note = nil; lock.allowEmergency = true
        lock.stage = .proof
        lock.proofDua = LockModel.proofDuas[0]
        lock.streak = 0
        lock.pledge = LockModel.pledges[0]; lock.pledgeNote = LockModel.pledgeNotes[1]
        save("6c-lock-proof", LockView(model: lock, primary: true, scale: 0.9) { _ in }, CGSize(width: 1512, height: 982))
        lock.pledge = LockModel.pledges[1]; lock.pledgeNote = LockModel.pledgeNotes[3]
        save("6c-lock-proof-2", LockView(model: lock, primary: true, scale: 0.9) { _ in }, CGSize(width: 1512, height: 982))

        let plan = RamadanPlan.shared
        if plan.goals.isEmpty { ["ختم القرآن مرتين", "صلاة التراويح كل يوم", "صدقة يومية لأهل غزة"].forEach { plan.add($0) } }
        save("8-ramadan-plan", RamadanPlanView(plan: plan), CGSize(width: 480, height: 600))
        notch.alert = .ramadan("رمضان بعد ١٠ يوم إن شاء الله", "عندك ٣ أهداف مكتوبة… جاهز؟")
        save("8b-notch-ramadan", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = nil
        let session = AdhkarSession()
        session.start(.morning); session.counts = [0: 1, 1: 3, 2: 1]
        save("9-adhkar-morning", AdhkarView(session: session, scrollable: false), CGSize(width: 520, height: 680))
        notch.alert = .nafl(.duha, Nafl.motivation[.duha]![2])
        save("9g-notch-duha", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .nafl(.qiyam, Nafl.motivation[.qiyam]![0])
        save("9h-notch-qiyam", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .naflCheck(.duha)
        save("9i-notch-duha-check", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .sadaqa(SadaqaLog.motivation[0])
        save("9e-notch-sadaqa", notchScene(), CGSize(width: 640, height: 200))
        SadaqaFlow.shared.nextIdea(); SadaqaFlow.shared.stage = .free
        save("9e2-notch-sadaqa-free", notchScene(), CGSize(width: 640, height: 200))
        SadaqaFlow.shared.stage = .skip
        save("9e3-notch-sadaqa-skip", notchScene(), CGSize(width: 640, height: 200))
        SadaqaFlow.shared.stage = .main
        let demoID = UUID()
        RahimStore.shared.people.append(Relative(id: demoID, name: "خالي", everyDays: 7, last: Date().addingTimeInterval(-12 * 86400)))
        notch.alert = .rahim(demoID, RahimStore.hadith[0], "كلّمه ولو دقيقتين")
        save("9j-notch-rahim", notchScene(), CGSize(width: 640, height: 200))
        RahimStore.shared.remove(demoID)
        notch.alert = .rahim(nil, RahimStore.hadith[2], "")
        save("9k-notch-rahim-friday", notchScene(), CGSize(width: 640, height: 200))
        notch.alert = .zakat("زكاتك بعد أسبوع إن شاء الله", "«وأقيموا الصلاة وآتوا الزكاة» · زكاتك تقريبًا ١٢٬٥٠٠ جنيه")
        save("9f-notch-zakat", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .wird(QuranWird.motivation[5])
        save("9d-notch-wird", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .adhkar(.morning, MorningEvening.motivation[.morning]![0])
        save("9b-notch-adhkar", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = .adhkar(.evening, MorningEvening.motivation[.evening]![0])
        save("9c-notch-adhkar-evening", notchScene(), CGSize(width: 640, height: 160))
        notch.alert = nil
        save("7-settings", SettingsView(settings: settings, engine: engine, onTestLock: {}, scrollable: false), CGSize(width: 640, height: 1500))
    }
}
