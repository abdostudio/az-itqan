import SwiftUI

// MARK: - Silat al-rahim (family ties) — names stay on this Mac only

struct Relative: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var everyDays: Int
    var last: Date?
    var snoozedUntil: Date?
    var snoozes = 0
}

final class RahimStore: ObservableObject {
    static let shared = RahimStore()
    private let key = "rahim.people"
    @Published var people: [Relative] { didSet { save() } }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([Relative].self, from: data) { people = list } else { people = [] }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(people) { UserDefaults.standard.set(data, forKey: key) }
    }

    func add() { people.append(Relative(name: "", everyDays: 7, last: Date())) }
    func remove(_ id: UUID) { people.removeAll { $0.id == id } }

    func daysSince(_ r: Relative, now: Date = Date()) -> Int? {
        guard let l = r.last else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: l),
                                               to: Calendar.current.startOfDay(for: now)).day
    }

    /// The most overdue person whose turn has come (and who isn't snoozed right now).
    func due(now: Date = Date()) -> Relative? {
        people.filter { r in
            !r.name.trimmingCharacters(in: .whitespaces).isEmpty
                && (r.snoozedUntil.map { now >= $0 } ?? true)
                && (daysSince(r, now: now).map { $0 >= r.everyDays } ?? true)
        }
        .max { (daysSince($0, now: now) ?? 999) - $0.everyDays < (daysSince($1, now: now) ?? 999) - $1.everyDays }
    }

    func markContacted(_ id: UUID) {
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        people[i].last = Date(); people[i].snoozedUntil = nil
    }
    /// "Remind me tonight": 8:30 pm, or in 3 hours if it's already late.
    func snooze(_ id: UUID) {
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        let cal = Calendar.current
        var tonight = cal.date(bySettingHour: 20, minute: 30, second: 0, of: Date()) ?? Date()
        if tonight.timeIntervalSinceNow < 30 * 60 { tonight = Date().addingTimeInterval(3 * 3600) }
        people[i].snoozedUntil = tonight
        people[i].snoozes += 1
    }
    /// "Not today": back tomorrow.
    func skipToday(_ id: UUID) {
        guard let i = people.firstIndex(where: { $0.id == id }) else { return }
        people[i].snoozedUntil = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)).addingTimeInterval(10 * 3600)
        people[i].snoozes += 1
    }
    /// How many different relatives were contacted in the last `n` days.
    func contacted(lastDays n: Int) -> Int {
        let from = Date().addingTimeInterval(-Double(n) * 86400)
        return people.filter { ($0.last ?? .distantPast) >= from && !$0.name.isEmpty }.count
    }

    static let frequencies: [(Int, String)] = [(1, tr("كل يوم")), (3, tr("كل ٣ أيام")), (7, tr("كل أسبوع")), (14, tr("كل أسبوعين")), (30, tr("كل شهر"))]

    // MARK: content
    static let hadith: [Msg] = [
        Msg(tr("من سرّه أن يُبسط له في رزقه ويُنسأ له في أثره فليصل رحمه"), tr("متفق عليه")),
        Msg(tr("من كان يؤمن بالله واليوم الآخر فليصل رحمه"), tr("متفق عليه")),
        Msg(tr("ليس الواصل بالمكافئ، ولكن الواصل الذي إذا قُطعت رحمه وصلها"), tr("رواه البخاري")),
        Msg(tr("الرحم معلّقة بالعرش تقول: من وصلني وصله الله، ومن قطعني قطعه الله"), tr("متفق عليه")),
        Msg(tr("واتقوا الله الذي تساءلون به والأرحام"), tr("النساء ١")),
        Msg(tr("وآتِ ذا القربى حقه"), tr("الإسراء ٢٦")),
        Msg(tr("الصدقة على المسكين صدقة، وعلى ذي الرحم ثنتان: صدقة وصلة"), tr("رواه الترمذي")),
        Msg(tr("لا يدخل الجنة قاطع"), tr("متفق عليه")),
        Msg(tr("مكالمة دقيقتين ممكن تفرق مع حد بيستناك أكتر مما تتخيل")),
        Msg(tr("صلة الرحم مش مستنية مناسبة… رسالة النهارده كفاية")),
    ]
    static let ideas: [String] = [
        tr("كلّمه ولو دقيقتين"), tr("ابعتله رسالة صوتية"), tr("اسأله عن صحته وأحواله"), tr("ابعتله دعوة حلوة"),
        tr("ابعتله صورة قديمة تجمعكم"), tr("اعزمه على قهوة أو زورة قريب"), tr("اسأله لو محتاج أي حاجة"),
        tr("قوله إنك افتكرته ودعيتله"), tr("شاركه خبر حلو حصلك"), tr("اسأله عن ولاده"),
    ]
    static let rotator = Rotator(key: "recent.rahim", memory: 4)
    static let ideaRotator = Rotator(key: "recent.rahimIdea", memory: 5)
}

// MARK: - Notch card

struct RahimNotch: View {
    @ObservedObject var model: NotchModel
    let personID: UUID?
    let msg: Msg
    let idea: String
    @ObservedObject var flow = RahimFlow.shared

    var body: some View {
        let store = RahimStore.shared
        let person = personID.flatMap { id in store.people.first { $0.id == id } }
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchHeight)
            VStack(alignment: .leading, spacing: 0) {
                switch flow.stage {
                case .main:
                    if let p = person {
                        let d = store.daysSince(p)
                        CardUI.row(icon: "person.2.fill", tint: Color(hex: 0x7FA8FF), title: tr("صلة الرحم"), titleColor: AZ.lime,
                                   text: d.map { $0 >= 2 ? trf("بقالك %@ يوم مكلّمتش %@… %@", AR.num($0), p.name, idea) : trf("النهارده دور %@… %@", p.name, idea) }
                                        ?? trf("النهارده دور %@… %@", p.name, idea),
                                   source: "\(msg.text)\(msg.source.map { " — \($0)" } ?? "")")
                        CardUI.bar {
                            CardUI.pill(tr("كلّمته"), "checkmark", primary: true) {
                                store.markContacted(p.id); finish(.done)
                            }
                            CardUI.pill(tr("فكّرني بالليل"), "moon", primary: false) {
                                store.snooze(p.id); finish(.later)
                            }
                            Spacer(minLength: 0)
                            CardUI.link(tr("مش النهارده")) { store.skipToday(p.id); finish(.skip) }
                        }
                    } else {
                        CardUI.row(icon: "person.2.fill", tint: Color(hex: 0x7FA8FF), title: tr("صلة الرحم"), titleColor: AZ.lime,
                                   text: msg.text, source: msg.source)
                        CardUI.bar {
                            CardUI.pill(tr("هكلّم حد النهارده"), "phone", primary: true) { finish(.done) }
                            Spacer(minLength: 0)
                            CardUI.link(tr("تمام")) { model.dismissAlert() }
                        }
                    }
                case .done:
                    CardUI.row(icon: "checkmark.seal.fill", tint: AZ.lime, title: nil, titleColor: .clear,
                               text: tr("ما شاء الله… ربنا يبارك فيكم"), source: tr("وصلت رحمك، ربنا يوصلك"))
                case .later:
                    CardUI.row(icon: "moon.fill", tint: AZ.violet, title: nil, titleColor: .clear,
                               text: tr("تمام… هنفكّرك بالليل إن شاء الله"), source: nil)
                case .skip:
                    CardUI.row(icon: "heart.fill", tint: Color(hex: 0x7FA8FF), title: nil, titleColor: .clear,
                               text: tr("ولا يهمك… بكرة إن شاء الله"), source: nil)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    private func finish(_ s: RahimFlow.Stage) {
        withAnimation(.easeOut(duration: 0.2)) { flow.stage = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak model] in
            if model?.isRahim == true { model?.dismissAlert() }
        }
    }
}

final class RahimFlow: ObservableObject {
    static let shared = RahimFlow()
    enum Stage { case main, done, later, skip }
    @Published var stage: Stage = .main
}

/// Shared pieces for the action cards in the notch (sadaqa, family ties).
enum CardUI {
    static func row(icon: String, tint: Color, title: String?, titleColor: Color, text: String, source: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.14))
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(tint)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                if let title { Text(title).font(AZFont.ui(11.5, .semibold)).foregroundColor(titleColor) }
                Text(text).font(AZFont.ui(14.5, .semibold)).lineLimit(2).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                if let source { Text(source).font(AZFont.ui(10.5)).foregroundColor(AZ.muted).lineLimit(1).minimumScaleFactor(0.8) }
            }
            Spacer(minLength: 0)
        }
    }

    static func bar<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5)
            HStack(spacing: 8) { c() }
        }
        .padding(.top, 12)
    }

    static func pill(_ title: String, _ icon: String, primary: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(title).font(AZFont.ui(11.5, primary ? .bold : .medium))
            }
            .foregroundColor(primary ? AZ.navy : .white)
            .padding(.horizontal, 13).padding(.vertical, 6)
            .background(Capsule().fill(primary ? AnyShapeStyle(AZ.lime) : AnyShapeStyle(AZ.violet.opacity(0.18))))
            .overlay(Capsule().strokeBorder(primary ? Color.clear : Color(hex: 0x7FA8FF).opacity(0.45), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    static func link(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(AZFont.ui(11)).foregroundColor(AZ.muted) }.buttonStyle(.plain)
    }
}

// MARK: - Settings section

struct RahimSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store = RahimStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(tr("فكّرني أكلّم أهلي حسب المواعيد اللي تحت (بالليل بعد العصر)"), isOn: $settings.rahimReminders).font(AZFont.ui(12.5))
            Toggle(tr("تذكير كل جمعة بفضل صلة الرحم"), isOn: $settings.rahimWeekly).font(AZFont.ui(12.5))
            Toggle(tr("تذكير بمعايدة الأهل في أول رمضان والعيدين"), isOn: $settings.rahimSeasons).font(AZFont.ui(12.5))
            ForEach($store.people) { $p in
                HStack(spacing: 8) {
                    Group {
                        if RenderMode.offscreen { Text(p.name.isEmpty ? tr("الاسم") : p.name) }
                        else { TextField(tr("الاسم (ماما، خالي، جدتي…)"), text: $p.name).textFieldStyle(.plain) }
                    }
                    .font(AZFont.ui(12))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
                    .frame(width: 170)
                    Picker("", selection: $p.everyDays) {
                        ForEach(RahimStore.frequencies, id: \.0) { Text($0.1).tag($0.0) }
                    }.labelsHidden().frame(width: 110)
                    Text(lastText(p)).font(AZFont.ui(10.5)).foregroundColor(AZ.muted).frame(width: 90, alignment: .leading)
                    Button { store.markContacted(p.id) } label: { Image(systemName: "checkmark.circle") }
                        .buttonStyle(.plain).foregroundColor(AZ.lime).help(tr("كلّمته النهارده"))
                    Button { store.remove(p.id) } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundColor(AZ.muted)
                }
            }
            Button { store.add() } label: { Label(tr("ضيف حد من أهلك"), systemImage: "plus.circle.fill") }
            Text(tr("الأسماء دي على جهازك بس، ومحدش بيشوفها غيرك.")).font(AZFont.ui(11)).foregroundColor(AZ.muted)
        }
    }

    private func lastText(_ p: Relative) -> String {
        guard let d = store.daysSince(p) else { return tr("لسه") }
        return d == 0 ? tr("كلّمته النهارده") : trf("من %@ يوم", AR.num(d))
    }
}
