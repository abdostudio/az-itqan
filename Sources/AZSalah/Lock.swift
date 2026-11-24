import SwiftUI
import AppKit

final class LockModel: ObservableObject {
    enum Stage { case main, snooze, proof }

    @Published var prayer: Prayer = .dhuhr
    @Published var friday = false
    @Published var adhanTime = Date()
    @Published var shownAt = Date()
    @Published var endsAt = Date()
    @Published var headline = ""
    @Published var message = Msg("")
    @Published var palestine = Msg("")
    @Published var snoozesLeft = 1
    @Published var appear = false
    @Published var stage: Stage = .main
    @Published var snoozeUnlockAt = Date()
    @Published var snoozeLine = Msg("")
    @Published var snoozeHadith = Msg("")
    @Published var streak = 0
    @Published var todayDone: Set<Prayer> = []
    /// Replaces "حان الآن موعد صلاة" on follow-up locks (e.g. "وقت العصر قرّب يخلص").
    @Published var note: String?
    @Published var allowEmergency = true
    /// The "try the prayer screen" preview: nothing is written to the prayer log.
    @Published var isTest = false
    /// Prayer-buddy QR code revealed on the prayer screen.
    @Published var showBuddy = false
    @Published var proofDua = Msg("")
    static let proofDuas: [Msg] = [
        Msg(tr("ربنا تقبّل منّا إنك أنت السميع العليم"), tr("البقرة ١٢٧")),
        Msg(tr("ربِّ اجعلني مقيم الصلاة ومن ذريتي، ربنا وتقبّل دعاء"), tr("إبراهيم ٤٠")),
        Msg(tr("اللهم أعنّي على ذكرك وشكرك وحسن عبادتك"), tr("رواه أبو داود")),
        Msg(tr("اللهم اجعلها خالصة لوجهك الكريم")),
        Msg(tr("الحمد لله الذي هدانا لهذا وما كنا لنهتدي لولا أن هدانا الله"), tr("الأعراف ٤٣")),
    ]
    static let proofRotator = Rotator(key: "recent.proofDua", memory: 2)
    /// What the user affirms by holding the button — changes every time.
    @Published var pledge = tr("والله صلّيت")
    @Published var pledgeNote = Msg("")
    static let pledges = [
        tr("والله صلّيت"), tr("أُشهد الله إني صلّيت"), tr("الحمد لله… صلّيت"), tr("ربنا شاهد إني صلّيت"),
        tr("صلّيت، والله على ما أقول شهيد"), tr("قمت وصلّيت، الحمد لله"), tr("صلّيتها بفضل الله"),
        tr("أُشهد الله إني صلّيت في وقتها"), tr("والله قمت وصلّيت"), tr("الله يشهد إني صلّيت"),
    ]
    static let pledgeNotes: [Msg] = [
        Msg(tr("الصلاة بينك وبين ربنا… الأداة بتفكّرك بس")),
        Msg(tr("ألم يعلم بأن الله يرى"), tr("العلق ١٤")),
        Msg(tr("ما يلفظ من قول إلا لديه رقيب عتيد"), tr("ق ١٨")),
        Msg(tr("الكلمة دي أمانة… وربنا مطّلع")),
        Msg(tr("يعلم خائنة الأعين وما تخفي الصدور"), tr("غافر ١٩")),
        Msg(tr("لو لسه مصلّيتش، مفيش مشكلة… قوم صلّي وارجع")),
    ]
    static let pledgeRotator = Rotator(key: "recent.pledge", memory: 4)
    static let pledgeNoteRotator = Rotator(key: "recent.pledgeNote", memory: 3)
    var doneAfter: TimeInterval = 180
    var snoozeMinutes = 5
    var snoozeWindowEnd = Date()
    var tz: TimeZone = .current

    /// Snooze is offered only while snoozes remain and we're still early after the adhan.
    func canSnooze(at now: Date) -> Bool { snoozesLeft > 0 && now < snoozeWindowEnd }

    func openSnooze() {
        snoozeLine = SnoozeMotivation.rotator.pick(SnoozeMotivation.lines)
        snoozeHadith = SnoozeMotivation.hadithRotator.pick(SnoozeMotivation.hadith)
        snoozeUnlockAt = Date().addingTimeInterval(8)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { stage = .snooze }
    }

    func back() { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { stage = .main } }
    func openProof() { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { stage = .proof } }
}

enum LockEnd { case prayed, timeUp, snoozed, emergency }

private final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class LockController {
    let model = LockModel()
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var activeObserver: Any?
    var onEnd: ((LockEnd) -> Void)?
    var isShowing: Bool { !windows.isEmpty }

    func show(prayer: Prayer, adhanTime: Date, duration: TimeInterval, settings: AppSettings,
              snoozesLeft: Int, friday: Bool, note: String? = nil, allowEmergency: Bool = true) {
        let pick = MessagePicker.adhanMessage(for: prayer, friday: friday)
        let tz = settings.location.timeZone
        LockLog.write("lock shown: prayer=\(prayer.rawValue) adhan=\(adhanTime) note=\(note ?? "-")")
        model.prayer = prayer
        model.friday = friday
        model.adhanTime = adhanTime
        model.shownAt = Date()
        model.endsAt = Date().addingTimeInterval(duration)
        model.headline = pick.headline
        model.message = pick.msg
        model.palestine = MessagePicker.palestineRotator.pick(Palestine.items)
        model.snoozesLeft = snoozesLeft
        model.doneAfter = TimeInterval(settings.doneAfterMinutes * 60)
        model.snoozeMinutes = settings.snoozeMinutes
        model.snoozeWindowEnd = adhanTime.addingTimeInterval(TimeInterval(settings.snoozeWindowMinutes * 60))
        model.tz = tz
        model.stage = .main
        model.isTest = false
        model.showBuddy = false
        model.proofDua = LockModel.proofRotator.pick(LockModel.proofDuas)
        model.pledge = LockModel.pledgeRotator.pick(LockModel.pledges.map { Msg($0) }).text
        model.pledgeNote = LockModel.pledgeNoteRotator.pick(LockModel.pledgeNotes)
        model.note = note
        model.allowEmergency = allowEmergency
        model.streak = PrayerLog.streak(until: Date(), tz: tz)
        model.todayDone = PrayerLog.prayed(on: Date(), tz: tz)

        if windows.isEmpty {
            model.appear = false
            for (i, screen) in NSScreen.screens.enumerated() {
                let w = KeyWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
                w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
                w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                w.isOpaque = false
                w.backgroundColor = .clear
                w.hasShadow = false
                w.isReleasedWhenClosed = false
                let scale = min(1, max(0.6, (screen.frame.height - 230) / 660))
                let view = LockView(model: model, primary: i == 0, scale: scale) { [weak self] reason in self?.finish(reason) }
                    .environment(\.layoutDirection, Lang.dir)
                w.contentView = NSHostingView(rootView: view)
                w.setFrame(screen.frame, display: true)
                w.alphaValue = 0
                w.orderFrontRegardless()
                windows.append(w)
            }
            windows.first?.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.6
                windows.forEach { $0.animator().alphaValue = 1 }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]

        activeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            guard let self, self.isShowing else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.windows.first?.makeKeyAndOrderFront(nil)
        }
        // No timer: the screen never unlocks by itself.
        timer?.invalidate(); timer = nil
    }

    func finish(_ reason: LockEnd) {
        guard isShowing else { return }
        switch reason {
        case _ where model.isTest: break
        case .prayed: PrayerLog.mark(model.prayer, on: model.adhanTime, tz: model.tz, .prayed)
        case .emergency: PrayerLog.mark(model.prayer, on: model.adhanTime, tz: model.tz, .emergency)
        default: break
        }
        timer?.invalidate(); timer = nil
        if let o = activeObserver { NotificationCenter.default.removeObserver(o); activeObserver = nil }
        NSApp.presentationOptions = []
        let closing = windows
        windows = []
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.45
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
        onEnd?(reason)
    }
}

// MARK: - Press-and-hold control

final class HoldState: ObservableObject {
    @Published var progress: Double = 0
    var timer: Timer?
}

/// A capsule that fills while pressed and fires after `seconds`.
struct HoldButton: View {
    let title: String
    let holdingTitle: String
    var seconds: Double = 3
    var tint: Color = AZ.lime
    var prominent = true
    let action: () -> Void
    @StateObject private var hold = HoldState()

    var body: some View {
        ZStack {
            Capsule().fill(prominent ? Color.white.opacity(0.10) : tint.opacity(0.10))
            GeometryReader { g in
                Capsule().fill(prominent ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(tint.opacity(0.35)))
                    .frame(width: max(0, g.size.width * hold.progress))
                    .frame(maxWidth: .infinity, alignment: .trailing) // fills right-to-left
            }
            Text(hold.progress > 0 ? holdingTitle : title)
                .font(AZFont.ui(prominent ? 15 : 12, prominent ? .bold : .medium))
                .foregroundColor(prominent ? (hold.progress > 0.5 ? AZ.navy : .white) : tint)
        }
        .frame(width: prominent ? 320 : 190, height: prominent ? 50 : 36)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(prominent ? AZ.lime.opacity(0.5) : tint.opacity(0.4), lineWidth: 0.8))
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: seconds, maximumDistance: 40, pressing: { pressing in
            hold.timer?.invalidate()
            if pressing {
                let start = Date()
                let t = Timer(timeInterval: 1 / 30, repeats: true) { [weak hold] _ in
                    hold?.progress = min(1, Date().timeIntervalSince(start) / seconds)
                }
                RunLoop.main.add(t, forMode: .common)
                hold.timer = t
            } else {
                withAnimation(.easeOut(duration: 0.2)) { hold.progress = 0 }
            }
        }, perform: {
            hold.timer?.invalidate()
            action()
        })
    }
}

// MARK: - View

struct LockView: View {
    @ObservedObject var model: LockModel
    @ObservedObject private var adhan = AdhanPlayer.shared
    let primary: Bool
    var scale: CGFloat = 1
    let onEnd: (LockEnd) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let now = tl.date
            // Counts down to when "صلّيت" unlocks; the screen itself only opens after the testimony.
            let left = model.shownAt.addingTimeInterval(model.doneAfter).timeIntervalSince(now)
            let total = max(1, model.doneAfter)
            ZStack {
                background
                VStack(spacing: 0) {
                    Spacer(minLength: 30)
                    archContent(left: left, total: total)
                        .scaleEffect(scale)
                        .frame(width: 640 * scale, height: 660 * scale)
                    Spacer(minLength: 20)
                    if primary { actions(now: now) }
                    Spacer(minLength: 24)
                    footer
                }
                .padding(.vertical, 28)
                .opacity(model.appear ? 1 : 0)
                .offset(y: model.appear ? 0 : 18)
                .blur(radius: primary && model.stage != .main ? 8 : 0)

                if primary && model.isTest {
                    VStack {
                        HStack {
                            Text(tr("تجربة · مش هتتسجل"))
                                .font(AZFont.ui(12, .semibold)).foregroundColor(AZ.navy)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(AZ.gold))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(28)
                }

                if primary && adhan.isPlaying {
                    VStack {
                        HStack {
                            Spacer()
                            Button { AdhanPlayer.shared.stop() } label: {
                                HStack(spacing: 6) { Image(systemName: "speaker.slash.fill"); Text(tr("اسكت الأذان")) }
                                    .font(AZFont.ui(12, .semibold)).foregroundColor(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.10)))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(28)
                    .transition(.opacity)
                }

                if primary && model.stage != .main {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .transition(.opacity)
                    Group {
                        if model.stage == .snooze { snoozeSheet(now: now) } else { proofSheet }
                    }
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
        .foregroundColor(.white)
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.1)) { model.appear = true } }
    }

    private var background: some View {
        ZStack {
            AZ.deepGradient
            RadialGradient(colors: [AZ.royal.opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: 620)
            RadialGradient(colors: [AZ.lime.opacity(0.10), .clear], center: UnitPoint(x: 0.5, y: 0.32), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }

    private func archContent(left: TimeInterval, total: TimeInterval) -> some View {
        ZStack {
            MihrabArch().fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.015)], startPoint: .top, endPoint: .bottom))
            AccentBorder(shape: ArchInsettable(), width: 1.4)
            VStack(spacing: 14) {
                Spacer(minLength: 96)
                ZStack {
                    Circle().fill(AZ.lime.opacity(0.12)).frame(width: 54, height: 54)
                    Image(systemName: "moon.stars.fill").font(.system(size: 20)).foregroundStyle(AZ.accentGradient)
                }
                Text(model.note ?? tr("حان الآن موعد صلاة")).font(AZFont.ui(17, .medium))
                    .foregroundColor(model.note == nil ? AZ.muted : AZ.gold)
                Text(model.prayer.arabic(friday: model.friday))
                    .font(AZFont.thuluth(86))
                    .foregroundStyle(LinearGradient(colors: [.white, AZ.lime], startPoint: .top, endPoint: .bottom))
                    .shadow(color: AZ.lime.opacity(0.25), radius: 18)
                    .padding(.top, -8)
                Text(AR.time(model.adhanTime, tz: model.tz, ampm: true)).font(AZFont.ui(14, .medium)).foregroundColor(AZ.muted)
                ornament
                Text(model.headline).font(AZFont.ui(18, .semibold)).foregroundColor(AZ.lime)
                Text(model.message.text)
                    .font(AZFont.naskh(30))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 520)
                    .fixedSize(horizontal: false, vertical: true)
                if let s = model.message.source {
                    Text(s).font(AZFont.ui(13)).foregroundColor(AZ.muted)
                }
                countdown(left: left, total: total).padding(.top, 8)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 44)
        }
        .frame(width: 640, height: 660)
    }

    private var ornament: some View {
        HStack(spacing: 10) {
            LinearGradient(colors: [.clear, AZ.gold.opacity(0.7)], startPoint: .leading, endPoint: .trailing).frame(width: 90, height: 1)
            AZSwoosh().fill(AZ.gold).frame(width: 20, height: 12)
            LinearGradient(colors: [AZ.gold.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing).frame(width: 90, height: 1)
        }
    }

    private func countdown(left: TimeInterval, total: TimeInterval) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
            Circle().trim(from: 0, to: CGFloat(max(0, left) / total))
                .stroke(AngularGradient(colors: [AZ.violet, AZ.lime, AZ.violet], center: .center),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: left)
            VStack(spacing: 2) {
                if left > 0 {
                    Text(AR.clock(left)).font(AZFont.ui(26, .bold).monospacedDigit()).foregroundColor(AZ.lime)
                    Text(tr("قوم اتوضّى")).font(AZFont.ui(10)).foregroundColor(AZ.muted)
                } else {
                    Image(systemName: "figure.stand").font(.system(size: 26)).foregroundColor(AZ.lime)
                    Text(tr("صلّيت؟ أكّد تحت")).font(AZFont.ui(10)).foregroundColor(AZ.muted)
                }
            }
        }
        .frame(width: 116, height: 116)
    }

    // MARK: main actions

    private func actions(now: Date) -> some View {
        let waitDone = model.shownAt.addingTimeInterval(model.doneAfter).timeIntervalSince(now)
        return VStack(spacing: 12) {
            Button { if waitDone <= 0 { model.openProof() } } label: {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(waitDone > 0 ? trf("صلّيت (متاح بعد %@)", AR.clock(waitDone)) : tr("صلّيت، الحمد لله"))
                }
                .font(AZFont.ui(15, .bold))
                .foregroundColor(AZ.navy)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Capsule().fill(waitDone > 0 ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(AZ.accentGradient)))
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                if model.canSnooze(at: now) {
                    Button { model.openSnooze() } label: {
                        Text(tr("محتاج تأجّل؟")).underline()
                    }
                    .buttonStyle(.plain)
                    if model.allowEmergency { Text("·") }
                }
                if model.allowEmergency {
                    HoldButton(title: tr("طوارئ حقيقية (اضغط مطوّل)"), holdingTitle: tr("استمر…"), seconds: 2,
                               tint: Color(hex: 0xFFB4A6), prominent: false) { onEnd(.emergency) }
                }
            }
            .font(AZFont.ui(12, .medium))
            .foregroundColor(AZ.muted.opacity(0.85))

            if model.showBuddy {
                EmptyView()       // make room for the QR card
            } else if model.canSnooze(at: now) {
                Text(trf("التأجيل مرة واحدة بس، ولحد %@ دقايق", AR.num(model.snoozeMinutes)))
                    .font(AZFont.ui(11)).foregroundColor(AZ.muted.opacity(0.6))
            } else {
                Text(tr("مفيش تأجيل… قوم صلّي دلوقتي")).font(AZFont.ui(11)).foregroundColor(AZ.muted.opacity(0.6))
            }

            // Prayer buddy: a small button that reveals the QR code for the phone.
            if primary && Buddy.enabled {
                if model.showBuddy {
                    BuddyQRCard(prayer: model.prayer, friday: model.friday)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { model.showBuddy = true } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill").font(.system(size: 11))
                            Text(Buddy.name.isEmpty ? tr("صلّي مع صاحبك") : trf("صلّي مع %@", Buddy.name))
                                .font(AZFont.ui(12, .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(AZ.violet.opacity(0.2)))
                        .overlay(Capsule().strokeBorder(Color(hex: 0x7FA8FF).opacity(0.5), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: sheets

    private func sheet<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 16) { content() }
            .padding(34)
            .frame(width: 600)
            .background(RoundedRectangle(cornerRadius: 26).fill(AZ.night.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
    }

    private func snoozeSheet(now: Date) -> some View {
        let wait = model.snoozeUnlockAt.timeIntervalSince(now)
        return sheet {
            Image(systemName: "hourglass").font(.system(size: 26)).foregroundColor(AZ.lime)
            Text(tr("مفيش حاجة أهم من الصلاة دلوقتي")).font(AZFont.ui(22, .bold))
            VStack(spacing: 4) {
                Text(model.snoozeLine.text)
                if let s = model.snoozeLine.source { Text(s) }
            }
            .font(AZFont.ui(15)).foregroundColor(AZ.muted).multilineTextAlignment(.center)
            VStack(spacing: 2) {
                Text(model.snoozeHadith.text)
                    .font(AZFont.naskh(22)).foregroundColor(.white.opacity(0.92)).multilineTextAlignment(.center)
                if let src = model.snoozeHadith.source {
                    Text(src).font(AZFont.ui(11)).foregroundColor(AZ.muted)
                }
            }
            .padding(.top, 4)
            HStack(spacing: 12) {
                Button { model.back() } label: {
                    HStack(spacing: 7) { Image(systemName: "figure.stand"); Text(tr("هقوم أصلّي")) }
                        .font(AZFont.ui(15, .bold)).foregroundColor(AZ.navy)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Capsule().fill(AZ.accentGradient))
                }
                .buttonStyle(.plain)
                Button { if wait <= 0 { onEnd(.snoozed) } } label: {
                    Text(wait > 0 ? trf("أأجّل %@ دقايق (استنى %@)", AR.num(model.snoozeMinutes), AR.num(Int(ceil(wait))))
                                  : trf("أأجّل %@ دقايق", AR.num(model.snoozeMinutes)))
                        .font(AZFont.ui(13, .semibold))
                        .foregroundColor(AZ.muted.opacity(wait > 0 ? 0.5 : 1))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            Text(model.snoozesLeft <= 1 ? tr("ده التأجيل الوحيد في الصلاة دي") : trf("باقي %@ تأجيل في الصلاة دي", AR.num(model.snoozesLeft)))
                .font(AZFont.ui(11)).foregroundColor(AZ.muted.opacity(0.7))
        }
    }

    private var proofSheet: some View {
        sheet {
            Text(trf("الحمد لله… صلّيت %@", model.prayer.arabic(friday: model.friday))).font(AZFont.naskh(36))
            VStack(spacing: 3) {
                Text(model.proofDua.text).font(AZFont.naskh(22)).foregroundColor(AZ.gold).multilineTextAlignment(.center)
                if let s = model.proofDua.source { Text(s).font(AZFont.ui(11)).foregroundColor(AZ.muted) }
            }
            VStack(spacing: 2) {
                Text(model.pledgeNote.text).font(AZFont.ui(12.5)).foregroundColor(AZ.muted)
                if let s = model.pledgeNote.source { Text(s).font(AZFont.ui(10.5)).foregroundColor(AZ.muted.opacity(0.7)) }
            }
            HoldButton(title: trf("اضغط ٣ ثواني: «%@»", model.pledge), holdingTitle: tr("تقبّل الله…"), seconds: 3) { onEnd(.prayed) }
            HStack(spacing: 12) {
                ForEach(Prayer.fard, id: \.self) { p in
                    let done = model.todayDone.contains(p)
                    VStack(spacing: 4) {
                        Circle().fill(done ? AnyShapeStyle(AZ.lime) : AnyShapeStyle(Color.white.opacity(0.12)))
                            .overlay(Circle().strokeBorder(p == model.prayer ? AZ.lime : .clear, lineWidth: 1.2))
                            .frame(width: 12, height: 12)
                        Text(p.arabic()).font(AZFont.ui(10.5)).foregroundColor(AZ.muted)
                    }
                }
            }
            .padding(.top, 4)
            Text(model.streak > 0 ? trf("%@ أيام متتالية ما فاتتكش صلاة — الحمد لله", AR.num(model.streak))
                                  : tr("ابدأ سلسلتك النهارده… خمس صلوات في وقتها"))
                .font(AZFont.ui(12.5, .semibold)).foregroundColor(AZ.lime)
            Text(tr("السجل ده على جهازك بس، ومحدش بيشوفه غيرك")).font(AZFont.ui(10.5)).foregroundColor(AZ.muted.opacity(0.7))
            Button { model.back() } label: { Text(tr("لسه هصلّي")).underline() }
                .buttonStyle(.plain).font(AZFont.ui(12)).foregroundColor(AZ.muted)
        }
    }

    // MARK: footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 14) {
            if primary {
                AZMark(letterColor: .white, slashColor: AZ.lime).frame(width: 46, height: 32)
            } else {
                Color.clear.frame(width: 46, height: 32)
            }
            Spacer()
            HStack(spacing: 10) {
                PalestineFlag().frame(width: 30, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("لا تنسَ فلسطين في سجودك")).font(AZFont.ui(12, .semibold))
                    Text(model.palestine.text).font(AZFont.ui(12)).foregroundColor(AZ.muted).lineLimit(1)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6))
            Spacer()
            Color.clear.frame(width: 46, height: 46)
        }
        .padding(.horizontal, 40)
    }
}

/// Insettable wrapper so the arch can use AccentBorder.
struct ArchInsettable: InsettableShape {
    var amount: CGFloat = 0
    func path(in rect: CGRect) -> Path { MihrabArch().path(in: rect.insetBy(dx: amount, dy: amount)) }
    func inset(by a: CGFloat) -> ArchInsettable { ArchInsettable(amount: amount + a) }
}
