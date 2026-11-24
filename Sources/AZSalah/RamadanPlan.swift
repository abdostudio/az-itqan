import SwiftUI
import AppKit

// MARK: - Data

struct RamadanGoal: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}

/// "My plan for Ramadan": goals written ahead of time, stored per Hijri year on this Mac.
final class RamadanPlan: ObservableObject {
    static let shared = RamadanPlan()

    @Published private(set) var goals: [RamadanGoal] = []
    @Published var draft = ""
    private(set) var year = 0
    private let settings = AppSettings.shared

    static let suggestions = [
        tr("ختم القرآن مرة على الأقل"), tr("صلاة التراويح كل يوم"), tr("صدقة يومية ولو قليلة"), tr("قيام العشر الأواخر"),
        tr("تفطير صائم"), tr("ورد أذكار الصباح والمساء"), tr("تقليل السوشيال ميديا"), tr("صلة الرحم"),
        tr("دعاء يومي لفلسطين"), tr("صدقة لأهل غزة"), tr("مشروع تصميم رمضاني"), tr("الاعتكاف ولو يوم"),
    ]

    private init() { reload() }

    /// The Ramadan being planned: the current one while in it, otherwise the next.
    func reload() {
        year = Self.targetYear(adjust: settings.hijriAdjust)
        if let data = UserDefaults.standard.data(forKey: key),
           let g = try? JSONDecoder().decode([RamadanGoal].self, from: data) {
            goals = g
        } else {
            goals = []
        }
    }

    private var key: String { "ramadanPlan.\(year)" }
    private func save() {
        if let data = try? JSONEncoder().encode(goals) { UserDefaults.standard.set(data, forKey: key) }
    }

    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !goals.contains(where: { $0.text == t }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { goals.append(RamadanGoal(text: t)) }
        save()
    }

    func addDraft() { add(draft); draft = "" }

    func toggle(_ g: RamadanGoal) {
        guard let i = goals.firstIndex(of: g) else { return }
        goals[i].done.toggle(); save()
    }

    func remove(_ g: RamadanGoal) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { goals.removeAll { $0.id == g.id } }
        save()
    }

    var pending: [RamadanGoal] { goals.filter { !$0.done } }

    // MARK: calendar helpers

    static func isRamadan(_ date: Date = Date(), adjust: Int) -> Bool { Hijri.components(date, adjust: adjust).month == 9 }

    /// Days until 1 Ramadan (0 while in Ramadan).
    static func daysUntil(from date: Date = Date(), adjust: Int) -> Int {
        if isRamadan(date, adjust: adjust) { return 0 }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        for n in 1...400 {
            if let d = cal.date(byAdding: .day, value: n, to: date), isRamadan(d, adjust: adjust) { return n }
        }
        return 0
    }

    /// Day number inside Ramadan (1…30), or nil outside it.
    static func dayOfRamadan(_ date: Date = Date(), adjust: Int) -> Int? {
        let h = Hijri.components(date, adjust: adjust)
        return h.month == 9 ? h.day : nil
    }

    static func targetYear(adjust: Int) -> Int {
        let h = Hijri.components(Date(), adjust: adjust)
        return h.month <= 9 ? h.year : h.year + 1
    }
}

// MARK: - Window

final class RamadanWindowController {
    private var window: NSWindow?

    func show() {
        RamadanPlan.shared.reload()
        if window == nil {
            let view = RamadanPlanView(plan: RamadanPlan.shared).environment(\.layoutDirection, Lang.dir)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
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

struct RamadanPlanView: View {
    @ObservedObject var plan: RamadanPlan
    var body: some View {
        let adjust = AppSettings.shared.hijriAdjust
        let inRamadan = RamadanPlan.isRamadan(adjust: adjust)
        let days = RamadanPlan.daysUntil(adjust: adjust)
        ZStack {
            AZ.deepGradient.ignoresSafeArea()
            RadialGradient(colors: [AZ.gold.opacity(0.12), .clear], center: UnitPoint(x: 0.5, y: 0.08), startRadius: 0, endRadius: 280)
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(AZ.gold.opacity(0.15))
                        Image(systemName: "moon.stars.fill").font(.system(size: 20)).foregroundColor(AZ.gold)
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trf("خطتي لرمضان %@", AR.num(plan.year))).font(AZFont.ui(20, .bold))
                        Text(inRamadan
                             ? trf("رمضان كريم… اليوم %@ من رمضان", AR.num(RamadanPlan.dayOfRamadan(adjust: adjust) ?? 1))
                             : trf("رمضان بعد %@ يوم إن شاء الله", AR.num(days)))
                            .font(AZFont.ui(12.5)).foregroundColor(AZ.gold)
                    }
                    Spacer()
                }

                Text(inRamadan ? tr("علّم على اللي عملته… وكمّل في الباقي") : tr("اكتب نيّتك من دلوقتي، والأداة هتفكّرك بيها أول ما رمضان ييجي."))
                    .font(AZFont.ui(12)).foregroundColor(AZ.muted)

                // Quick add
                HStack(spacing: 8) {
                    TextField(tr("اكتب هدف واضغط Enter… مثلاً: ختم القرآن مرتين"), text: $plan.draft)
                        .textFieldStyle(.plain)
                        .font(AZFont.ui(13.5))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AZ.lime.opacity(0.35), lineWidth: 0.8))
                        .onSubmit { plan.addDraft() }
                    Button { plan.addDraft() } label: {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(AZ.navy)
                            .frame(width: 38, height: 38).background(Circle().fill(AZ.accentGradient))
                    }.buttonStyle(.plain)
                }

                // Suggestions
                FlowChips(items: RamadanPlan.suggestions.filter { s in !plan.goals.contains { $0.text == s } }) { plan.add($0) }

                // Goals
                ScrollView {
                    VStack(spacing: 6) {
                        if plan.goals.isEmpty {
                            Text(tr("لسه مفيش أهداف… ابدأ بواحد صغير")).font(AZFont.ui(12)).foregroundColor(AZ.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                        ForEach(plan.goals) { g in
                            HStack(spacing: 10) {
                                Button { plan.toggle(g) } label: {
                                    Image(systemName: g.done ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 17)).foregroundColor(g.done ? AZ.lime : AZ.muted)
                                }.buttonStyle(.plain)
                                Text(g.text).font(AZFont.ui(13.5, .medium))
                                    .strikethrough(g.done, color: AZ.muted)
                                    .foregroundColor(g.done ? AZ.muted : .white)
                                Spacer()
                                Button { plan.remove(g) } label: {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.muted)
                                        .frame(width: 22, height: 22).background(Circle().fill(Color.white.opacity(0.06)))
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AZ.cardGradient))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AZ.line, lineWidth: 0.5))
                        }
                    }
                }

                HStack {
                    Text(trf("%@ أهداف · %@ اتعملت", AR.num(plan.goals.count), AR.num(plan.goals.filter(\.done).count)))
                    Spacer()
                    Text(tr("محفوظة على جهازك بس"))
                }
                .font(AZFont.ui(10.5)).foregroundColor(AZ.muted)
            }
            .padding(.horizontal, 24).padding(.top, 36).padding(.bottom, 18)
        }
        .foregroundColor(.white)
        .frame(width: 480, height: 600)
    }
}

/// Wrapping row of tappable suggestion chips.
struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { s in
                Button { onTap(s) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 8.5, weight: .bold))
                        Text(s)
                    }
                    .font(AZFont.ui(11, .medium)).foregroundColor(AZ.lime)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill(AZ.lime.opacity(0.10)))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            // SwiftUI mirrors custom layouts in right-to-left, so this fills from the right there.
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
