import SwiftUI
import AppKit

// MARK: - Content (Hisn al-Muslim selection)

struct Dhikr: Identifiable {
    let id: Int
    let text: String
    let count: Int
    let note: String?
}

enum MorningEvening {
    enum Kind: String { case morning, evening
        var title: String { self == .morning ? tr("أذكار الصباح") : tr("أذكار المساء") }
    }

    static let ayatAlKursi = tr("الله لا إله إلا هو الحي القيوم، لا تأخذه سنة ولا نوم، له ما في السماوات وما في الأرض، من ذا الذي يشفع عنده إلا بإذنه، يعلم ما بين أيديهم وما خلفهم، ولا يحيطون بشيء من علمه إلا بما شاء، وسع كرسيه السماوات والأرض، ولا يئوده حفظهما، وهو العلي العظيم")
    static let ikhlas = tr("قل هو الله أحد ۝ الله الصمد ۝ لم يلد ولم يولد ۝ ولم يكن له كفوًا أحد")
    static let falaq = tr("قل أعوذ برب الفلق ۝ من شر ما خلق ۝ ومن شر غاسق إذا وقب ۝ ومن شر النفاثات في العقد ۝ ومن شر حاسد إذا حسد")
    static let nas = tr("قل أعوذ برب الناس ۝ ملك الناس ۝ إله الناس ۝ من شر الوسواس الخناس ۝ الذي يوسوس في صدور الناس ۝ من الجنة والناس")

    static func list(_ k: Kind) -> [Dhikr] {
        let m = k == .morning
        var items: [(String, Int, String?)] = [
            (ayatAlKursi, 1, tr("آية الكرسي")),
            (ikhlas, 3, tr("سورة الإخلاص")),
            (falaq, 3, tr("سورة الفلق")),
            (nas, 3, tr("سورة الناس")),
            (m ? tr("أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير، ربِّ أسألك خير ما في هذا اليوم وخير ما بعده، وأعوذ بك من شر ما في هذا اليوم وشر ما بعده، ربِّ أعوذ بك من الكسل وسوء الكبر، ربِّ أعوذ بك من عذاب في النار وعذاب في القبر")
               : tr("أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير، ربِّ أسألك خير ما في هذه الليلة وخير ما بعدها، وأعوذ بك من شر ما في هذه الليلة وشر ما بعدها، ربِّ أعوذ بك من الكسل وسوء الكبر، ربِّ أعوذ بك من عذاب في النار وعذاب في القبر"), 1, nil),
            (m ? tr("اللهم بك أصبحنا، وبك أمسينا، وبك نحيا، وبك نموت، وإليك النشور")
               : tr("اللهم بك أمسينا، وبك أصبحنا، وبك نحيا، وبك نموت، وإليك المصير"), 1, nil),
            (tr("اللهم أنت ربي لا إله إلا أنت، خلقتني وأنا عبدك، وأنا على عهدك ووعدك ما استطعت، أعوذ بك من شر ما صنعت، أبوء لك بنعمتك عليّ، وأبوء بذنبي فاغفر لي، فإنه لا يغفر الذنوب إلا أنت"), 1, tr("سيد الاستغفار")),
            (m ? tr("اللهم إني أصبحت أُشهدك، وأُشهد حملة عرشك، وملائكتك، وجميع خلقك، أنك أنت الله لا إله إلا أنت وحدك لا شريك لك، وأن محمدًا عبدك ورسولك")
               : tr("اللهم إني أمسيت أُشهدك، وأُشهد حملة عرشك، وملائكتك، وجميع خلقك، أنك أنت الله لا إله إلا أنت وحدك لا شريك لك، وأن محمدًا عبدك ورسولك"), 4, nil),
            (m ? tr("اللهم ما أصبح بي من نعمة أو بأحد من خلقك فمنك وحدك لا شريك لك، فلك الحمد ولك الشكر")
               : tr("اللهم ما أمسى بي من نعمة أو بأحد من خلقك فمنك وحدك لا شريك لك، فلك الحمد ولك الشكر"), 1, nil),
            (tr("اللهم عافني في بدني، اللهم عافني في سمعي، اللهم عافني في بصري، لا إله إلا أنت. اللهم إني أعوذ بك من الكفر والفقر، وأعوذ بك من عذاب القبر، لا إله إلا أنت"), 3, nil),
            (tr("حسبي الله لا إله إلا هو، عليه توكلت وهو رب العرش العظيم"), 7, nil),
            (tr("اللهم إني أسألك العفو والعافية في الدنيا والآخرة، اللهم إني أسألك العفو والعافية في ديني ودنياي وأهلي ومالي، اللهم استر عوراتي وآمن روعاتي، اللهم احفظني من بين يدي ومن خلفي، وعن يميني وعن شمالي، ومن فوقي، وأعوذ بعظمتك أن أُغتال من تحتي"), 1, nil),
            (tr("اللهم عالم الغيب والشهادة، فاطر السماوات والأرض، رب كل شيء ومليكه، أشهد أن لا إله إلا أنت، أعوذ بك من شر نفسي، ومن شر الشيطان وشركه، وأن أقترف على نفسي سوءًا أو أجرّه إلى مسلم"), 1, nil),
            (tr("بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم"), 3, nil),
            (tr("رضيت بالله ربًّا، وبالإسلام دينًا، وبمحمد ﷺ نبيًّا"), 3, nil),
            (tr("يا حيّ يا قيوم برحمتك أستغيث، أصلح لي شأني كله، ولا تكلني إلى نفسي طرفة عين"), 1, nil),
            (m ? tr("أصبحنا على فطرة الإسلام، وعلى كلمة الإخلاص، وعلى دين نبينا محمد ﷺ، وعلى ملة أبينا إبراهيم حنيفًا مسلمًا وما كان من المشركين")
               : tr("أمسينا على فطرة الإسلام، وعلى كلمة الإخلاص، وعلى دين نبينا محمد ﷺ، وعلى ملة أبينا إبراهيم حنيفًا مسلمًا وما كان من المشركين"), 1, nil),
        ]
        if m {
            items.append((tr("سبحان الله وبحمده عدد خلقه، ورضا نفسه، وزنة عرشه، ومداد كلماته"), 3, nil))
        } else {
            items.append((tr("أعوذ بكلمات الله التامات من شر ما خلق"), 3, nil))
        }
        items += [
            (tr("لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير"), 10, nil),
            (tr("سبحان الله وبحمده"), 100, nil),
            (tr("أستغفر الله وأتوب إليه"), 100, nil),
            (tr("اللهم صلِّ وسلِّم على نبينا محمد"), 10, nil),
        ]
        return items.enumerated().map { Dhikr(id: $0.offset, text: $0.element.0, count: $0.element.1, note: $0.element.2) }
    }

    /// Motivation shown with the reminder — rotates.
    static let motivation: [Kind: [Msg]] = [
        .morning: [
            Msg(tr("افتح يومك بذكر الله قبل ما تفتح الإيميل"), tr("خمس دقايق بتحرسك اليوم كله")),
            Msg(tr("أذكار الصباح حصنك… البسه قبل ما تنزل الدنيا"), tr("قبل أي ميتنج، قبل أي تصميم")),
            Msg(tr("من قال: بسم الله الذي لا يضر مع اسمه شيء… ثلاث مرات، لم تصبه فجأة بلاء"), tr("رواه أبو داود والترمذي")),
            Msg(tr("وسبّحوه بكرةً وأصيلًا"), tr("الأحزاب ٤٢")),
            Msg(tr("اليوم اللي بيبدأ بذكر الله… بيبقى أبرك"), tr("قولها وإنت بتشرب قهوتك")),
        ],
        .evening: [
            Msg(tr("قبل ما الشمس تغيب… اقفل يومك في حفظ ربنا"), tr("أذكار المساء خمس دقايق")),
            Msg(tr("اليوم خلص بكل ضغطه… سلّمه لربنا وارتاح"), tr("قول أذكار المساء دلوقتي")),
            Msg(tr("من قال حين يمسي: أعوذ بكلمات الله التامات من شر ما خلق، لم تضره حُمة تلك الليلة"), tr("رواه الترمذي")),
            Msg(tr("ألا بذكر الله تطمئن القلوب"), tr("الرعد ٢٨")),
            Msg(tr("بات في حفظ الله… بكلمتين قبل الليل"), tr("أذكار المساء مستنياك")),
        ],
    ]
    static let rotator = Rotator(key: "recent.adhkarMotivation", memory: 3)

    /// Which set is relevant now: morning from Fajr to Dhuhr, evening from Asr to Isha.
    static func current(engine: PrayerEngine) -> Kind? {
        let now = engine.now, t = engine.today
        if let f = t[.fajr], let d = t[.dhuhr], now >= f, now < d { return .morning }
        if let a = t[.asr], let i = t[.isha], now >= a, now < i { return .evening }
        return nil
    }

    // Per-day completion
    private static func doneKey(_ k: Kind) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "adhkarDone.\(k.rawValue).\(c.year!)-\(c.month!)-\(c.day!)"
    }
    static func isDone(_ k: Kind) -> Bool { UserDefaults.standard.bool(forKey: doneKey(k)) }
    static func markDone(_ k: Kind) { UserDefaults.standard.set(true, forKey: doneKey(k)) }
}

// MARK: - Reader model

final class AdhkarSession: ObservableObject {
    static let shared = AdhkarSession()
    @Published var kind: MorningEvening.Kind = .morning
    @Published var counts: [Int: Int] = [:]
    @Published var index = 0
    var items: [Dhikr] { MorningEvening.list(kind) }

    func start(_ k: MorningEvening.Kind) {
        if k != kind { counts = [:]; index = 0 }
        kind = k
    }

    var current: Dhikr { items[min(index, items.count - 1)] }

    /// Tap in the notch reader: count, and move on once this dhikr is complete.
    func tapCurrent() {
        let d = current
        tap(d)
        if counts[d.id, default: 0] >= d.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.advance() }
        }
    }

    func advance() {
        let list = items
        if let next = list.indices.first(where: { $0 > index && counts[list[$0].id, default: 0] < list[$0].count })
            ?? list.indices.first(where: { counts[list[$0].id, default: 0] < list[$0].count }) {
            withAnimation(.easeInOut(duration: 0.2)) { index = next }
        }
    }

    func step(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.2)) { index = max(0, min(items.count - 1, index + delta)) }
    }

    func tap(_ d: Dhikr) {
        let c = counts[d.id, default: 0]
        guard c < d.count else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { counts[d.id] = c + 1 }
        if c + 1 == d.count { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        if completed == items.count { MorningEvening.markDone(kind) }
    }

    var completed: Int { items.filter { counts[$0.id, default: 0] >= $0.count }.count }
}

// MARK: - Window

final class AdhkarWindowController {
    private var window: NSWindow?
    let session = AdhkarSession.shared

    func show(_ k: MorningEvening.Kind) {
        session.start(k)
        if window == nil {
            let view = AdhkarView(session: session).environment(\.layoutDirection, Lang.dir)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.appearance = NSAppearance(named: .darkAqua)
            w.animationBehavior = .none
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: view)
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct AdhkarView: View {
    @ObservedObject var session: AdhkarSession
    var scrollable = true

    var body: some View {
        let items = session.items
        let morning = session.kind == .morning
        ZStack {
            AZ.deepGradient.ignoresSafeArea()
            RadialGradient(colors: [(morning ? AZ.gold : AZ.violet).opacity(0.16), .clear],
                           center: UnitPoint(x: 0.5, y: 0.05), startRadius: 0, endRadius: 300)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill((morning ? AZ.gold : AZ.violet).opacity(0.18))
                        Image(systemName: morning ? "sunrise.fill" : "sunset.fill").font(.system(size: 19))
                            .foregroundColor(morning ? AZ.gold : AZ.violet)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.kind.title).font(AZFont.ui(20, .bold))
                        Text(tr("اضغط على الذِكر كل ما تقوله… والعدّاد بيعدّ معاك")).font(AZFont.ui(11.5)).foregroundColor(AZ.muted)
                    }
                    Spacer()
                    // switch morning / evening
                    HStack(spacing: 2) {
                        ForEach([MorningEvening.Kind.morning, .evening], id: \.rawValue) { k in
                            Button { session.start(k) } label: {
                                Text(k == .morning ? tr("الصباح") : tr("المساء"))
                                    .font(AZFont.ui(11, .semibold))
                                    .foregroundColor(session.kind == k ? AZ.navy : AZ.muted)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(session.kind == k ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.clear)))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }

                // progress
                VStack(spacing: 5) {
                    HStack {
                        Text(trf("خلّصت %@ من %@", AR.num(session.completed), AR.num(items.count)))
                        Spacer()
                        if session.completed == items.count { Text(tr("تقبّل الله… ما شاء الله")).foregroundColor(AZ.lime) }
                    }
                    .font(AZFont.ui(11, .medium)).foregroundColor(AZ.muted)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule().fill(AZ.accentGradient)
                                .frame(width: max(6, g.size.width * CGFloat(session.completed) / CGFloat(max(1, items.count))))
                        }
                    }
                    .frame(height: 5)
                }

                if scrollable {
                    ScrollView { list(items) }
                } else {
                    list(Array(items.prefix(3))) // previews only
                }
            }
            .padding(.horizontal, 22).padding(.top, 34).padding(.bottom, 16)
        }
        .foregroundColor(.white)
        .frame(width: 520, height: 680)
    }

    private func list(_ items: [Dhikr]) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { d in
                let c = session.counts[d.id, default: 0]
                let done = c >= d.count
                Button { session.tap(d) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if let note = d.note { Text(note).font(AZFont.ui(10.5, .bold)).foregroundColor(AZ.gold) }
                        Text(d.text)
                            .font(AZFont.naskh(21))
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(done ? AZ.muted : .white)
                        HStack {
                            Spacer()
                            HStack(spacing: 5) {
                                if done { Image(systemName: "checkmark") }
                                Text(d.count == 1 ? (done ? tr("تم") : tr("مرة")) : "\(AR.num(c)) / \(AR.num(d.count))")
                            }
                            .font(AZFont.ui(11, .bold))
                            .foregroundColor(done ? AZ.navy : AZ.lime)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(done ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(AZ.lime.opacity(0.12))))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AZ.cardGradient))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(done ? AZ.lime.opacity(0.35) : AZ.line, lineWidth: done ? 0.8 : 0.5))
                    .opacity(done ? 0.7 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
