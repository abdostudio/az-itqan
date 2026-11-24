import SwiftUI
import AppKit

// MARK: - Sadaqa (private, on-device)

final class SadaqaLog: ObservableObject {
    static let shared = SadaqaLog()
    @Published private(set) var revision = 0

    private static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "sadaqa.\(c.year!)-\(c.month!)-\(c.day!)"
    }
    func gave(on date: Date = Date()) -> Bool { UserDefaults.standard.bool(forKey: Self.key(date)) }
    func markGiven(_ on: Bool = true) {
        UserDefaults.standard.set(on, forKey: Self.key(Date()))
        revision += 1
    }
    func count(lastDays n: Int) -> Int {
        (0..<n).filter { gave(on: Calendar.current.date(byAdding: .day, value: -$0, to: Date())!) }.count
    }

    static let motivation: [Msg] = [
        Msg(tr("ما نقصت صدقةٌ من مال"), tr("رواه مسلم")),
        Msg(tr("اتقوا النار ولو بشقّ تمرة"), tr("متفق عليه")),
        Msg(tr("الصدقة تطفئ الخطيئة كما يطفئ الماء النار"), tr("رواه الترمذي")),
        Msg(tr("مثل الذين ينفقون أموالهم في سبيل الله كمثل حبة أنبتت سبع سنابل"), tr("البقرة ٢٦١")),
        Msg(tr("صدقة صغيرة كل يوم أحسن من كبيرة مرة… والقليل الدائم أحب إلى الله")),
        Msg(tr("فكّر في أهل غزة النهارده… ولو بالقليل من جهة موثوقة")),
    ]
    static let rotator = Rotator(key: "recent.sadaqa", memory: 3)

    /// Sadaqa without money — small, real things from the Sunnah and daily life.
    static let freeIdeas: [Msg] = [
        Msg(tr("تبسّمك في وجه أخيك صدقة"), tr("رواه الترمذي")),
        Msg(tr("الكلمة الطيبة صدقة"), tr("متفق عليه")),
        Msg(tr("كل تسبيحة صدقة، وكل تحميدة صدقة، وكل تهليلة صدقة"), tr("رواه مسلم")),
        Msg(tr("إماطة الأذى عن الطريق صدقة"), tr("متفق عليه")),
        Msg(tr("أمرٌ بالمعروف صدقة، ونهيٌ عن المنكر صدقة"), tr("رواه مسلم")),
        Msg(tr("تعين الرجل في دابته فتحمله عليها صدقة"), tr("متفق عليه")),
        Msg(tr("إرشادك الرجل في أرض الضلال صدقة"), tr("رواه الترمذي")),
        Msg(tr("كل معروف صدقة"), tr("رواه البخاري")),
        Msg(tr("وفي بُضع أحدكم صدقة… حتى نيّتك الحلوة في بيتك أجر"), tr("رواه مسلم")),
        Msg(tr("ما أطعمت نفسك وأهلك فهو لك صدقة"), tr("رواه أحمد")),
        Msg(tr("ابعت رسالة حلوة لحد زعلان أو تعبان")),
        Msg(tr("كلّم حد كبير في عيلتك واسأل عليه")),
        Msg(tr("ادعي لحد بظهر الغيب… دعوة المسلم لأخيه مستجابة"), tr("رواه مسلم")),
        Msg(tr("علّم حد حاجة بتعرفها في شغلك")),
        Msg(tr("ساعد زميل في حاجة واقف فيها")),
        Msg(tr("سامح حد زعّلك… والعفو صدقة على نفسك")),
        Msg(tr("شارك محتوى نافع أو آية… الدال على الخير كفاعله"), tr("رواه مسلم")),
        Msg(tr("حط مية للطيور أو القطط في البلكونة")),
        Msg(tr("اسمع لحد محتاج يتكلم… من غير ما تقاطعه")),
        Msg(tr("قول كلمة شكر لحد بيخدمك: عامل، سواق، بواب")),
        Msg(tr("فرّح طفل بحاجة بسيطة")),
        Msg(tr("اكتب تقييم حلو لحد شغله عاجبك… وادعيله")),
        Msg(tr("صلّي ركعتين الضحى… تجزئ عن صدقة كل مفاصلك"), tr("رواه مسلم")),
        Msg(tr("انصح حد بلطف في حاجة ممكن تنفعه")),
    ]
    static let freeRotator = Rotator(key: "recent.freeSadaqa", memory: 10)
}

// MARK: - Zakat

final class ZakatStore: ObservableObject {
    static let shared = ZakatStore()
    private let d = UserDefaults.standard

    @Published var cash: Double { didSet { d.set(cash, forKey: "zakat.cash") } }
    @Published var gold24: Double { didSet { d.set(gold24, forKey: "zakat.gold24") } }
    @Published var gold21: Double { didSet { d.set(gold21, forKey: "zakat.gold21") } }
    @Published var goldPrice: Double { didSet { d.set(goldPrice, forKey: "zakat.goldPrice") } }
    @Published var receivables: Double { didSet { d.set(receivables, forKey: "zakat.receivables") } }
    @Published var debts: Double { didSet { d.set(debts, forKey: "zakat.debts") } }
    @Published var currency: String { didSet { d.set(currency, forKey: "zakat.currency") } }
    /// Hijri date (month/day) the zakat year completes — 0 = not set.
    @Published var dueMonth: Int { didSet { d.set(dueMonth, forKey: "zakat.dueMonth") } }
    @Published var dueDay: Int { didSet { d.set(dueDay, forKey: "zakat.dueDay") } }

    private init() {
        cash = d.double(forKey: "zakat.cash")
        gold24 = d.double(forKey: "zakat.gold24")
        gold21 = d.double(forKey: "zakat.gold21")
        goldPrice = d.double(forKey: "zakat.goldPrice")
        receivables = d.double(forKey: "zakat.receivables")
        debts = d.double(forKey: "zakat.debts")
        currency = d.string(forKey: "zakat.currency") ?? tr("جنيه")
        dueMonth = d.integer(forKey: "zakat.dueMonth")
        dueDay = d.integer(forKey: "zakat.dueDay")
    }

    /// Gold valued as 24k equivalent; nisab = 85 g of 24k gold.
    var goldValue: Double { (gold24 + gold21 * 21 / 24) * goldPrice }
    var total: Double { max(0, cash + goldValue + receivables - debts) }
    var nisab: Double { 85 * goldPrice }
    var reachesNisab: Bool { goldPrice > 0 && total >= nisab }
    var zakat: Double { reachesNisab ? total * 0.025 : 0 }

    /// Days until the next due date (nil if not set).
    func daysUntilDue(adjust: Int) -> Int? {
        guard dueMonth > 0, dueDay > 0 else { return nil }
        let cal = Calendar.current
        for n in 0...400 {
            let day = cal.date(byAdding: .day, value: n, to: Date())!
            let h = Hijri.components(day, adjust: adjust)
            if h.month == dueMonth && h.day == dueDay { return n }
        }
        return nil
    }

    static func money(_ v: Double) -> String {
        let f = NumberFormatter(); f.locale = AR.locale; f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

// MARK: - Giving tab (Sadaqa + Zakat)

struct GivingTab: View {
    @ObservedObject var sadaqa = SadaqaLog.shared
    @ObservedObject var zakat = ZakatStore.shared
    let adjust: Int
    @StateObject private var line = LineHolder(msg: SadaqaLog.rotator.pick(SadaqaLog.motivation))

    var body: some View {
        VStack(spacing: 8) {
            // Sadaqa
            HStack(spacing: 10) {
                Image(systemName: "hands.and.sparkles.fill").font(.system(size: 15)).foregroundColor(AZ.gold)
                    .frame(width: 32, height: 32).background(Circle().fill(AZ.gold.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(sadaqa.gave() ? tr("طلّعت صدقة النهارده ✓ تقبّل الله") : tr("صدقة النهارده")).font(AZFont.ui(12.5, .semibold))
                    Text(line.msg.text + (line.msg.source.map { " · \($0)" } ?? ""))
                        .font(AZFont.ui(9.5)).foregroundColor(AZ.muted).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Text(trf("%@/٧ أيام", AR.num(sadaqa.count(lastDays: 7))))
                    .font(AZFont.ui(10, .semibold)).foregroundColor(AZ.gold)
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { sadaqa.markGiven(!sadaqa.gave()) } } label: {
                    Text(sadaqa.gave() ? tr("تراجع") : tr("طلّعت ✓")).font(AZFont.ui(10.5, .bold))
                        .foregroundColor(sadaqa.gave() ? AZ.muted : AZ.navy)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(sadaqa.gave() ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(AZ.accentGradient)))
                }.buttonStyle(.plain)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [AZ.gold.opacity(0.12), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))

            // Zakat calculator
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label(tr("حاسبة الزكاة"), systemImage: "scalemass.fill").font(AZFont.ui(12.5, .semibold)).foregroundColor(.white)
                    Spacer()
                    if let n = zakat.daysUntilDue(adjust: adjust) {
                        Text(n == 0 ? tr("ميعاد زكاتك النهارده") : trf("ميعادها بعد %@ يوم إن شاء الله", AR.num(n)))
                            .font(AZFont.ui(10)).foregroundColor(AZ.gold)
                    } else {
                        Text(tr("حدد ميعادها من الإعدادات")).font(AZFont.ui(10)).foregroundColor(AZ.muted)
                    }
                }
                Grid(horizontalSpacing: 8, verticalSpacing: 5) {
                    GridRow {
                        field(tr("الفلوس والمدخرات"), $zakat.cash)
                        field(tr("سعر جرام دهب ٢٤"), $zakat.goldPrice)
                    }
                    GridRow {
                        field(tr("دهب عيار ٢٤ (جرام)"), $zakat.gold24)
                        field(tr("دهب عيار ٢١ (جرام)"), $zakat.gold21)
                    }
                    GridRow {
                        field(tr("فلوس ليك عند حد"), $zakat.receivables)
                        field(tr("ديون عليك"), $zakat.debts)
                    }
                }
                HStack(spacing: 6) {
                    if zakat.goldPrice <= 0 {
                        Text(tr("اكتب سعر جرام الدهب عشان نحسب النصاب")).foregroundColor(AZ.muted)
                    } else if zakat.reachesNisab {
                        Text(tr("زكاتك:")).foregroundColor(AZ.muted)
                        Text("\(ZakatStore.money(zakat.zakat)) \(zakat.currency)").font(AZFont.ui(14, .bold)).foregroundColor(AZ.lime)
                        Text(trf("· ٢٫٥٪ من %@", ZakatStore.money(zakat.total))).foregroundColor(AZ.muted)
                    } else {
                        Text(trf("مالك أقل من النصاب (%@ %@)… مفيش زكاة", ZakatStore.money(zakat.nisab), zakat.currency)).foregroundColor(AZ.muted)
                    }
                    Spacer(minLength: 0)
                }
                .font(AZFont.ui(10.5, .medium))
                .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(AZ.cardGradient))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))

            Text(tr("حساب تقريبي على نصاب الدهب (٨٥ جرام). في الحالات الخاصة اسأل أهل العلم."))
                .font(AZFont.ui(9)).foregroundColor(AZ.muted.opacity(0.8))
        }
    }

    private func field(_ title: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(title).font(AZFont.ui(9.5)).foregroundColor(AZ.muted).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Group {
                if RenderMode.offscreen {
                    // AppKit text fields can't be drawn offscreen (snapshots / promo video)
                    Text(value.wrappedValue == 0 ? tr("٠") : ZakatStore.money(value.wrappedValue))
                } else {
                    TextField(tr("٠"), value: value, format: .number).textFieldStyle(.plain)
                }
            }
                .font(AZFont.ui(11.5, .semibold).monospacedDigit())
                .multilineTextAlignment(.leading)
                .frame(width: 78)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08)))
        }
    }
}

/// True while rendering images/video offscreen.
enum RenderMode { static var offscreen = false }

final class LineHolder: ObservableObject {
    @Published var msg: Msg
    init(msg: Msg) { self.msg = msg }
}

// MARK: - Weekly / monthly report

struct ReportTab: View {
    static func shortDay(_ d: Date) -> String {
        [tr("أحد"), tr("اتنين"), tr("تلات"), tr("أربع"), tr("خميس"), tr("جمعة"), tr("سبت")][Calendar.current.component(.weekday, from: d) - 1]
    }
    @ObservedObject var engine: PrayerEngine
    @StateObject private var mode = LineHolder(msg: Msg("week"))

    var body: some View {
        let days = mode.msg.text == "week" ? 7 : 30
        let tz = engine.tz
        let cal = Calendar.current
        let dates: [Date] = (0..<days).reversed().map { cal.date(byAdding: .day, value: -$0, to: engine.now)! }
        // Prayers already due: full days + today's prayers whose time has passed.
        let dueToday = Prayer.fard.filter { (engine.today[$0] ?? .distantFuture) <= engine.now }.count
        let expected = 5 * (days - 1) + dueToday
        let prayed = min(expected, dates.reduce(0) { $0 + PrayerLog.prayed(on: $1, tz: tz).count })
        let rate = expected > 0 ? Double(prayed) / Double(expected) : 0
        let sadaqa = SadaqaLog.shared.count(lastDays: days)
        let streak = PrayerLog.streak(until: engine.now, tz: tz)

        VStack(spacing: 9) {
            HStack(spacing: 2) {
                ForEach(["week", "month"], id: \.self) { m in
                    Button { withAnimation(.easeInOut(duration: 0.2)) { mode.msg = Msg(m) } } label: {
                        Text(m == "week" ? tr("الأسبوع") : tr("الشهر"))
                            .font(AZFont.ui(11, .semibold))
                            .foregroundColor(mode.msg.text == m ? AZ.navy : AZ.muted)
                            .padding(.horizontal, 14).padding(.vertical, 4)
                            .background(Capsule().fill(mode.msg.text == m ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.clear)))
                    }.buttonStyle(.plain)
                }
            }
            .padding(2).background(Capsule().fill(Color.white.opacity(0.06)))

            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
                    Circle().trim(from: 0, to: rate).stroke(AZ.accentGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(trf("%@٪", AR.num(Int((rate * 100).rounded())))).font(AZFont.ui(15, .bold))
                }
                .frame(width: 66, height: 66)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trf("%@ من %@ صلاة اتأكدت", AR.num(prayed), AR.num(expected))).font(AZFont.ui(13, .semibold))
                    Text(rate >= 0.9 ? tr("ما شاء الله… الحمد لله على التوفيق") : rate >= 0.6 ? tr("قريب جدًا… كمّل وربنا يعينك") : tr("ابدأ من الصلاة الجاية… ربنا يعينك"))
                        .font(AZFont.ui(10.5)).foregroundColor(rate >= 0.9 ? AZ.lime : AZ.muted)
                    HStack(spacing: 12) {
                        Label(trf("%@ أيام متتالية", AR.num(streak)), systemImage: "flame.fill")
                        Label(trf("صدقة %@ من %@ يوم", AR.num(sadaqa), AR.num(days)), systemImage: "hands.and.sparkles.fill")
                        Label(trf("الضحى %@ · القيام %@", AR.num(Nafl.count(.duha, lastDays: days)), AR.num(Nafl.count(.qiyam, lastDays: days))), systemImage: "sun.max.fill")
                        if !RahimStore.shared.people.isEmpty {
                            Label(trf("وصلت %@ من أهلك", AR.num(RahimStore.shared.contacted(lastDays: days))), systemImage: "person.2.fill")
                        }
                    }
                    .font(AZFont.ui(10)).foregroundColor(AZ.gold)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)

            if days == 7 {
                // 7 days × 5 prayers
                HStack(spacing: 6) {
                    ForEach(dates, id: \.self) { d in
                        let done = PrayerLog.prayed(on: d, tz: tz)
                        VStack(spacing: 4) {
                            Text(Self.shortDay(d)).font(AZFont.ui(9.5)).foregroundColor(AZ.muted)
                            ForEach(Prayer.fard, id: \.self) { p in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(done.contains(p) ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                                    .frame(height: 9)
                            }
                            Circle().fill(SadaqaLog.shared.gave(on: d) ? AZ.gold : Color.white.opacity(0.06)).frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                // 30-day heatmap: brightness = prayers confirmed that day
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 15), spacing: 4) {
                    ForEach(dates, id: \.self) { d in
                        let n = PrayerLog.prayed(on: d, tz: tz).count
                        RoundedRectangle(cornerRadius: 4)
                            .fill(n == 0 ? AnyShapeStyle(Color.white.opacity(0.07)) : AnyShapeStyle(AZ.lime.opacity(0.2 + 0.16 * Double(n))))
                            .frame(height: 22)
                            .overlay(alignment: .bottomTrailing) {
                                if SadaqaLog.shared.gave(on: d) { Circle().fill(AZ.gold).frame(width: 5, height: 5).padding(3) }
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
            HStack(spacing: 12) {
                Label(tr("صلاة اتأكدت"), systemImage: "square.fill").foregroundColor(AZ.lime)
                Label(tr("يوم فيه صدقة"), systemImage: "circle.fill").foregroundColor(AZ.gold)
                Spacer()
                Text(tr("السجل على جهازك بس")).foregroundColor(AZ.muted)
            }
            .font(AZFont.ui(9))
            .padding(.horizontal, 6)
        }
    }
}
