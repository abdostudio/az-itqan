import SwiftUI
import AppKit
import CoreLocation
import ServiceManagement

// MARK: - Location

final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Result<Location, Error>) -> Void)?

    struct Failure: LocalizedError { let errorDescription: String? }

    func request(_ done: @escaping (Result<Location, Error>) -> Void) {
        completion = done
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(.failure(Failure(errorDescription: tr("الوصول للموقع مقفول. افتحه من إعدادات النظام ← الخصوصية ← خدمات الموقع."))))
        default: manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        guard completion != nil else { return }
        switch m.authorizationStatus {
        case .authorizedAlways, .authorized: m.requestLocation()
        case .denied, .restricted:
            finish(.failure(Failure(errorDescription: tr("الوصول للموقع مقفول. افتحه من إعدادات النظام ← الخصوصية ← خدمات الموقع."))))
        default: break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        CLGeocoder().reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "ar")) { [weak self] marks, _ in
            let p = marks?.first
            let name = p?.locality ?? p?.administrativeArea ?? tr("موقعي")
            let tz = p?.timeZone?.identifier ?? TimeZone.current.identifier
            self?.finish(.success(Location(name: name, latitude: loc.coordinate.latitude,
                                           longitude: loc.coordinate.longitude, timeZoneID: tz)))
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(Failure(errorDescription: tr("مقدرناش نحدد الموقع. جرّب تاني أو اختار مدينتك من القائمة."))))
    }

    private func finish(_ r: Result<Location, Error>) {
        DispatchQueue.main.async { self.completion?(r); self.completion = nil }
    }
}

// MARK: - Settings window

final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: AppSettings
    private let engine: PrayerEngine
    var onTestLock: (() -> Void)?

    init(settings: AppSettings, engine: PrayerEngine) { self.settings = settings; self.engine = engine }

    func show() {
        if window == nil {
            let view = SettingsView(settings: settings, engine: engine, onTestLock: { [weak self] in self?.onTestLock?() })
                .environment(\.layoutDirection, Lang.dir)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.appearance = NSAppearance(named: .darkAqua)
            w.contentView = NSHostingView(rootView: view)
            w.isReleasedWhenClosed = false
            w.animationBehavior = .none
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // No control gets keyboard focus on open, so no animated focus ring appears.
        window?.makeFirstResponder(nil)
        DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(nil) }
    }
}

final class SettingsUIState: ObservableObject {
    @Published var locating = false
    @Published var locError: String?
    @Published var loginItem = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var engine: PrayerEngine
    let onTestLock: () -> Void
    var scrollable = true
    @StateObject private var ui = SettingsUIState()
    private let locator = LocationProvider()

    var body: some View {
        ZStack {
            AZ.deepGradient.ignoresSafeArea()
            if scrollable { ScrollView { form } } else { form }
        }
        .foregroundColor(.white)
        .frame(width: 640, height: scrollable ? 720 : nil)
        .tint(AZ.lime)
    }

    private var form: some View {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    todayCard
                    section(tr("الموقع"), "location.fill") { locationRows }
                    section(tr("طريقة الحساب"), "function") { methodRows }
                    section(tr("تعديل المواعيد بالدقايق (عشان تطابق مسجدك)"), "slider.horizontal.3") { offsetRows }
                    section(tr("شاشة الصلاة"), "lock.fill") { lockRows }
                    section(tr("التنبيهات والتذكير"), "bell.fill") { alertRows }
                    section(tr("ورد القرآن اليومي"), "book.fill") { wirdRows }
                    section(tr("الصدقة والزكاة"), "hands.and.sparkles.fill") { givingRows }
                    section(tr("صلة الرحم"), "person.2.fill") { RahimSettings(settings: settings) }
                    section(tr("عام"), "gearshape.fill") { generalRows }
                    credits
                    footer
                }
                .padding(.horizontal, 26)
                .padding(.top, 34)
                .padding(.bottom, 24)
    }

    // MARK: pieces

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [AZ.royal, AZ.indigo], startPoint: .top, endPoint: .bottom))
                Image(systemName: "moon.stars.fill").font(.system(size: 20)).foregroundColor(AZ.lime)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("AZ Itqan").font(AZFont.ui(22, .bold))
                Text(tr("إتقان في الشغل… وإتقان في الصلاة")).font(AZFont.ui(12)).foregroundColor(AZ.muted)
            }
            Spacer()
            Text("v\(UpdateChecker.shared.current)").font(AZFont.ui(10, .medium)).foregroundColor(AZ.lime)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(AZ.lime.opacity(0.5), lineWidth: 0.6))
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(trf("النهارده في %@", settings.location.name)).font(AZFont.ui(13, .semibold))
                Spacer()
                Text(Hijri.string(engine.now, adjust: settings.hijriAdjust)).font(AZFont.ui(11)).foregroundColor(AZ.muted)
            }
            HStack(spacing: 6) {
                ForEach(Prayer.allCases, id: \.self) { p in
                    VStack(spacing: 3) {
                        Text(p.arabic(friday: engine.isFriday)).font(AZFont.ui(10.5)).foregroundColor(AZ.muted)
                        Text(engine.today[p].map { AR.time($0, tz: engine.tz) } ?? "—").font(AZFont.ui(15, .semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AZ.cardGradient))
                }
            }
            let fasts = engine.fastingTomorrow
            if !fasts.isEmpty {
                Label(tr("بكرة إن شاء الله: ") + fasts.map(\.title).joined(separator: " · "), systemImage: "moon.stars")
                    .font(AZFont.ui(11.5)).foregroundColor(AZ.gold)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [AZ.royal.opacity(0.35), AZ.indigo.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AZ.line, lineWidth: 0.6))
    }

    private func section<C: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(AZFont.ui(12.5, .semibold)).foregroundColor(AZ.lime)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.6))
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack { Text(label).font(AZFont.ui(12.5)); Spacer(); control() }
    }

    private func stepper(_ label: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, unit: String) -> some View {
        row(label) {
            Stepper(value: value, in: range) {
                Text("\(AR.num(value.wrappedValue)) \(unit)").font(AZFont.ui(12.5, .medium).monospacedDigit()).foregroundColor(AZ.lime)
            }
        }
    }

    // MARK: rows

    @ViewBuilder private var locationRows: some View {
        if !settings.locationConfirmed || !settings.timeZoneMatches {
            VStack(alignment: .leading, spacing: 6) {
                Label(settings.timeZoneMatches ? tr("أكّد مدينتك الأول") : tr("توقيت المدينة المختارة مختلف عن توقيت جهازك"),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(AZFont.ui(12.5, .semibold)).foregroundColor(AZ.gold)
                Text(tr("شاشة الصلاة مش هتقفل الجهاز لحد ما مدينتك تبقى صح، عشان ما تظهرش في وقت غلط."))
                    .font(AZFont.ui(11)).foregroundColor(AZ.muted)
                if settings.timeZoneMatches {
                    Button(tr("أيوه، دي مدينتي ✓")) { settings.locationConfirmed = true }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(AZ.gold.opacity(0.10)))
        }
        row(tr("المدينة")) {
            Picker("", selection: Binding(get: { settings.cityID }, set: { id in
                settings.cityID = id
                settings.locationConfirmed = true
                if let c = Cities.byID(id) { settings.methodID = c.method }
            })) {
                if let g = settings.gpsLocation { Text(trf("📍 %@ (موقعي)", g.name)).tag("gps") }
                ForEach(Cities.countries, id: \.self) { country in
                    Section(Cities.countryName(country)) {
                        ForEach(Cities.all.filter { $0.country == country }) { c in Text(c.displayName).tag(c.id) }
                    }
                }
            }
            .labelsHidden().frame(width: 230)
        }
        HStack {
            Button {
                ui.locating = true; ui.locError = nil
                locator.request { result in
                    ui.locating = false
                    switch result {
                    case .success(let loc):
                        settings.gpsLocation = loc
                        settings.cityID = "gps"
                        settings.locationConfirmed = true
                        settings.methodID = Cities.methodNear(lat: loc.latitude, lng: loc.longitude)
                    case .failure(let e): ui.locError = e.localizedDescription
                    }
                }
            } label: {
                Label(ui.locating ? tr("بنحدد مكانك…") : tr("حدد موقعي تلقائي"), systemImage: "location.circle")
            }
            Spacer()
            Text(String(format: tr("%.3f، %.3f"), settings.location.latitude, settings.location.longitude))
                .font(AZFont.ui(10.5).monospacedDigit()).foregroundColor(AZ.muted)
        }
        if let locError = ui.locError { Text(locError).font(AZFont.ui(11)).foregroundColor(Color(hex: 0xFFB4A6)) }
        Text(trf("المنطقة الزمنية: %@", settings.location.timeZoneID)).font(AZFont.ui(10.5)).foregroundColor(AZ.muted)
    }

    @ViewBuilder private var methodRows: some View {
        row(tr("الهيئة")) {
            Picker("", selection: $settings.methodID) {
                ForEach(CalcMethod.all) { m in Text(m.arabic).tag(m.id) }
            }.labelsHidden().frame(width: 280)
        }
        row(tr("حساب العصر")) {
            Picker("", selection: $settings.asrSchool) {
                ForEach(AsrSchool.allCases) { a in Text(a.arabic).tag(a) }
            }.labelsHidden().frame(width: 220)
        }
        row(tr("البلاد البعيدة عن خط الاستواء")) {
            Picker("", selection: $settings.highLat) {
                ForEach(HighLatRule.allCases) { r in Text(r.arabic).tag(r) }
            }.labelsHidden().frame(width: 220)
        }
        stepper(tr("تعديل التاريخ الهجري (رؤية الهلال)"), $settings.hijriAdjust, -2...2, unit: tr("يوم"))
    }

    @ViewBuilder private var offsetRows: some View {
        ForEach(Prayer.allCases, id: \.self) { p in
            stepper(p.arabic(), Binding(get: { settings.offsets[p.rawValue] ?? 0 },
                                        set: { settings.offsets[p.rawValue] = $0 }), -30...30, unit: tr("د"))
        }
    }

    @ViewBuilder private var lockRows: some View {
        Toggle(tr("اقفل الشاشة وقت الأذان"), isOn: $settings.lockEnabled).font(AZFont.ui(12.5))
        if settings.lockEnabled {
            HStack(spacing: 6) {
                ForEach(Prayer.fard, id: \.self) { p in
                    let on = settings.lockPrayers.contains(p.rawValue)
                    Button { settings.toggleLock(p, !on) } label: {
                        Text(p.arabic()).font(AZFont.ui(12, .medium))
                            .foregroundColor(on ? AZ.navy : .white)
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(Capsule().fill(on ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.white.opacity(0.07))))
                    }.buttonStyle(.plain)
                }
            }
            Text(tr("الشاشة مش بتفتح لوحدها… بتفتح بس لما تأكد إنك صلّيت (أو تأجّل / طوارئ)."))
                .font(AZFont.ui(11)).foregroundColor(AZ.muted)
            stepper(tr("زرار «صلّيت» يظهر بعد"), $settings.doneAfterMinutes, 0...15, unit: tr("دقيقة"))
            stepper(tr("مدة التأجيل"), $settings.snoozeMinutes, 1...5, unit: tr("دقيقة"))
            stepper(tr("عدد مرات التأجيل في الصلاة"), $settings.maxSnoozes, 0...2, unit: tr("مرة"))
            stepper(tr("التأجيل متاح بس في أول"), $settings.snoozeWindowMinutes, 3...15, unit: tr("دقيقة بعد الأذان"))
            stepper(tr("بعد الطوارئ، اقفل تاني بعد"), $settings.followUpMinutes, 5...60, unit: tr("دقيقة"))
            Toggle(tr("ما تقفلش وأنا في ميتنج (Zoom / Teams / Meet / FaceTime)"), isOn: $settings.deferInMeetings).font(AZFont.ui(12.5))
            Button { onTestLock() } label: { Label(tr("جرّب شاشة الصلاة"), systemImage: "play.circle") }
        }
        BuddySettings(settings: settings)
    }

    @ViewBuilder private var alertRows: some View {
        stepper(tr("تنبيه قبل الأذان"), $settings.preAlertMinutes, 0...60, unit: tr("دقيقة"))
        Toggle(tr("الذِكر ظاهر على طول تحت النوتش (بيغطي شريط صغير)"), isOn: $settings.alwaysShowDhikr).font(AZFont.ui(12.5))
        row(settings.alwaysShowDhikr ? tr("الذِكر يتغير كل") : tr("النوتش تكبر بذِكر كل")) {
            Picker("", selection: $settings.reminderMinutes) {
                Text(tr("مقفول")).tag(0)
                ForEach([1, 2, 5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { m in Text(trf("%@ دقيقة", AR.num(m))).tag(m) }
            }.labelsHidden().frame(width: 140)
        }
        if !settings.alwaysShowDhikr {
            stepper(tr("مدة ظهور الذِكر"), $settings.peekSeconds, 4...60, unit: tr("ثانية"))
        }
        Toggle(tr("تذكير بفلسطين ضمن التذكيرات"), isOn: $settings.palestineReminders).font(AZFont.ui(12.5))
        Toggle(tr("تذكير بأذكار الصباح (بعد الفجر) والمساء (بعد العصر)"), isOn: $settings.adhkarReminders).font(AZFont.ui(12.5))
        Toggle(tr("تذكير بصلاة الضحى (نص الوقت بين الشروق والظهر)"), isOn: $settings.duhaReminder).font(AZFont.ui(12.5))
        Toggle(tr("تذكير بقيام الليل (أول الثلث الأخير من الليل)"), isOn: $settings.qiyamReminder).font(AZFont.ui(12.5))
        Toggle(tr("تذكير بأيام الصيام (الاثنين والخميس، الأيام البيض، عرفة، عاشوراء، ست شوال…)"), isOn: $settings.fastingReminders).font(AZFont.ui(12.5))
        Toggle(tr("صوت مع الأذان"), isOn: $settings.soundEnabled).font(AZFont.ui(12.5))
        if settings.soundEnabled {
            row(tr("الصوت")) {
                Picker("", selection: $settings.soundName) {
                    Text(tr("أذان منوّع (كل مرة مختلف)")).tag("adhan-mix")
                    ForEach(AdhanPlayer.voices, id: \.id) { v in Text(v.name).tag(v.id) }
                    Divider()
                    ForEach(AdhanPlayer.systemSounds, id: \.self) { Text(trf("نغمة: %@", $0)).tag($0) }
                    Text(tr("ملف من جهازي")).tag("custom")
                }.labelsHidden().frame(width: 220)
                Button { SoundPlayer.play(settings, prayer: .asr) } label: { Image(systemName: "play.fill") }
                Button { SoundPlayer.stop() } label: { Image(systemName: "stop.fill") }
            }
            row(tr("علو الصوت")) {
                Slider(value: $settings.adhanVolume, in: 0.1...1).frame(width: 180)
            }
            if settings.soundName == "custom" {
                HStack {
                    Button(tr("اختار ملف صوت…")) {
                        let p = NSOpenPanel()
                        p.allowedContentTypes = [.audio]
                        p.allowsMultipleSelection = false
                        if p.runModal() == .OK, let url = p.url { settings.customSoundPath = url.path }
                    }
                    Text(settings.customSoundPath.isEmpty ? tr("مفيش ملف") : (settings.customSoundPath as NSString).lastPathComponent)
                        .font(AZFont.ui(11)).foregroundColor(AZ.muted).lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder private var givingRows: some View {
        row(tr("تذكير بالصدقة")) {
            Picker("", selection: $settings.sadaqaReminder) {
                Text(tr("كل يوم (بعد الظهر)")).tag("daily")
                Text(tr("كل جمعة")).tag("friday")
                Text(tr("مقفول")).tag("off")
            }.labelsHidden().frame(width: 170)
        }
        ZakatDueRow(zakat: ZakatStore.shared)
        Text(tr("حاسبة الزكاة نفسها في النوتش ← قسم «العطاء».")).font(AZFont.ui(11)).foregroundColor(AZ.muted)
    }

    @ViewBuilder private var wirdRows: some View {
        Toggle(tr("تذكير بالورد اليومي في النوتش"), isOn: $settings.wirdEnabled).font(AZFont.ui(12.5))
        stepper(tr("وردي كل يوم"), $settings.wirdPages, 1...40, unit: tr("صفحة"))
        row(tr("فكّرني بعد صلاة")) {
            Picker("", selection: $settings.wirdAfter) {
                ForEach(Prayer.fard, id: \.self) { p in Text(p.arabic()).tag(p.rawValue) }
            }.labelsHidden().frame(width: 120)
        }
        stepper(tr("أنا واقف عند صفحة"), Binding(get: { QuranWird.shared.page }, set: { QuranWird.shared.setPage($0) }),
                1...QuranWird.totalPages, unit: "")
        let days = Int((Double(QuranWird.totalPages) / Double(max(1, settings.wirdPages))).rounded(.up))
        Text(trf("بالمعدل ده هتختم كل %@ يوم تقريبًا بإذن الله", AR.num(days)))
            .font(AZFont.ui(11)).foregroundColor(AZ.lime)
    }

    @ViewBuilder private var generalRows: some View {
        row("اللغة · Language") {
            Picker("", selection: Binding(get: { Lang.code }, set: { Lang.switchTo($0) })) {
                Text("العربية").tag("ar")
                Text("English").tag("en")
            }.pickerStyle(.segmented).labelsHidden().frame(width: 180)
        }
        UpdateRow(checker: UpdateChecker.shared)
        row(tr("شكل النوتش وهي هادية")) {
            Picker("", selection: $settings.idleLevel) {
                Text(tr("خط")).tag(0)
                Text(tr("نقطة")).tag(1)
                Text(tr("نص صغير")).tag(2)
                Text(tr("كاملة")).tag(3)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 270)
        }
        Text([tr("في حجم الكاميرا، وتحتها خط رفيع زي عداد البنزين: بيفضى لحد الأذان… والصلاة بترجّع روحك"),
              tr("نقطة صغيرة جنب الكاميرا، لونها بيتغير كل ما الصلاة تقرب"),
              tr("اسم الصلاة والوقت بخط صغير (بيغطي شوية من البار)"),
              tr("الصلاة والعداد كاملين (ممكن يغطوا أيقونات في البار)")][min(3, max(0, settings.idleLevel))])
            .font(AZFont.ui(11)).foregroundColor(AZ.muted)
        Text(tr("وفي كل الأحوال: الصلاة والعداد بيظهروا آخر ١٥ دقيقة قبل الأذان، ولما تقف عليها بالماوس"))
            .font(AZFont.ui(11)).foregroundColor(AZ.muted.opacity(0.8))
        row(tr("مكان النوتش")) {
            Picker("", selection: $settings.islandFloating) {
                Text(tr("فوق النوتش (ثابت)")).tag(false)
                Text(tr("حر — اسحبه لأي مكان")).tag(true)
            }.labelsHidden().frame(width: 200)
        }
        if settings.islandFloating {
            row(tr("حجم النوتش")) {
                Slider(value: $settings.islandScale, in: 0.8...1.5, step: 0.05).frame(width: 170)
                Text(trf("%@٪", AR.num(Int((settings.islandScale * 100).rounded()))))
                    .font(AZFont.ui(12, .medium).monospacedDigit()).foregroundColor(AZ.lime).frame(width: 44)
                Button(tr("١٠٠٪")) { settings.islandScale = 1 }
            }
            HStack {
                Text(tr("اسحب النوتش الصغير بالماوس وحطه في المكان اللي يريّحك.")).font(AZFont.ui(11)).foregroundColor(AZ.muted)
                Spacer()
                Button(tr("رجّعه لمكانه")) { NotchPanel.resetPositions(); settings.objectWillChange.send() }
            }
        }
        row(tr("يظهر على")) {
            Picker("", selection: $settings.displayMode) {
                Text(tr("كل الشاشات")).tag("all")
                Text(tr("شاشة الماك بوك (النوتش)")).tag("notch")
                Text(tr("الشاشة الرئيسية بس")).tag("main")
            }.labelsHidden().frame(width: 200)
        }
        Toggle(tr("يفتح مع تشغيل الماك"), isOn: Binding(get: { ui.loginItem }, set: { on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                ui.loginItem = on; ui.loginError = nil
            } catch {
                ui.loginError = trf("مقدرناش نغيّرها: %@", error.localizedDescription)
            }
        })).font(AZFont.ui(12.5))
        if let loginError = ui.loginError { Text(loginError).font(AZFont.ui(11)).foregroundColor(Color(hex: 0xFFB4A6)) }
    }

    private var credits: some View {
        Text(AdhanPlayer.credits).font(AZFont.ui(9.5)).foregroundColor(AZ.muted.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            // AZ mark + name (leading side)
            HStack(spacing: 9) {
                AZMark().frame(width: 32, height: 22)
                Text("Abdelrahman Ahmed").font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: 0x081434))
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer()
            // Social links (other side)
            HStack(spacing: 6) {
                SocialButton(path: SocialIcons.behance, help: "Behance", url: "https://www.behance.net/Abdostudio")
                SocialButton(path: SocialIcons.linkedin, help: "LinkedIn", url: "https://www.linkedin.com/in/abdostudio/")
                SocialButton(path: SocialIcons.email, help: "abdstudio.me@gmail.com", url: "mailto:abdstudio.me@gmail.com")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        .padding(.top, 6)
    }

}

/// Clickable social icon in the white AZ footer.
struct SocialButton: View {
    let path: String
    let help: String
    let url: String
    @StateObject private var hover = HoverState()

    var body: some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            SVGShape(d: path)
                .fill(hover.on ? Color(hex: 0x1356D4) : Color(hex: 0x162950))
                .frame(width: 16, height: 16)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(hover.on ? Color(hex: 0xEDF2FF) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(hover.on ? Color(hex: 0xDCE5FA) : Color.clear, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover.on = $0; if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        .accessibilityLabel(help)
    }
}

final class HoverState: ObservableObject { @Published var on = false }


/// Version + "check for updates" in settings.
struct UpdateRow: View {
    @ObservedObject var checker: UpdateChecker
    var body: some View {
        HStack(spacing: 10) {
            Text(trf("النسخة %@", checker.current)).font(AZFont.ui(12.5))
            if !checker.status.isEmpty {
                Text(checker.status).font(AZFont.ui(11)).foregroundColor(checker.latest != nil ? AZ.lime : AZ.muted)
            }
            Spacer()
            if checker.latest != nil {
                Button(tr("حمّل التحديث")) { checker.download() }
            }
            Button(tr("شيّك على التحديثات")) { checker.check(manual: true) }
        }
    }
}


/// Hijri due date + currency for zakat.
struct ZakatDueRow: View {
    @ObservedObject var zakat: ZakatStore
    var body: some View {
        HStack(spacing: 8) {
            Text(tr("ميعاد زكاتك (هجري)")).font(AZFont.ui(12.5))
            Spacer()
            Picker("", selection: $zakat.dueDay) {
                Text("—").tag(0)
                ForEach(1...30, id: \.self) { Text(AR.num($0)).tag($0) }
            }.labelsHidden().frame(width: 64)
            Picker("", selection: $zakat.dueMonth) {
                Text("—").tag(0)
                ForEach(1...12, id: \.self) { Text(Hijri.monthNames[$0 - 1]).tag($0) }
            }.labelsHidden().frame(width: 120)
            TextField(tr("العملة"), text: $zakat.currency).frame(width: 64)
        }
    }
}
