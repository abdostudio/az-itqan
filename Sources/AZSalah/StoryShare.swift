import SwiftUI
import AppKit

// MARK: - What goes on the card

/// Sharing is kept for the iPhone version; on the Mac every entry point is hidden.
enum StoryFeature { static let onMac = false }

enum StoryPool {
    static let rotator = Rotator(key: "recent.story", memory: 25)

    private static func isHadith(_ m: Msg) -> Bool {
        guard let s = m.source else { return false }
        return s.contains("رواه") || s.contains("متفق")
    }
    /// A Quran reference looks like "البقرة ٤٥" / "Al-Baqarah 45": ends with a number.
    private static func isAyah(_ m: Msg) -> Bool {
        guard let s = m.source, !isHadith(m), !s.contains("—") else { return false }
        return s.last.map { $0.isNumber } ?? false
    }
    private static var allMotivation: [Msg] {
        Motivation.general + Motivation.friday + Motivation.byPrayer.values.flatMap { $0 }
    }

    static func items(_ kind: StoryItem.Kind) -> [StoryItem] {
        switch kind {
        case .dhikr:
            return (Adhkar.reminders.filter { !isAyah($0) } + Adhkar.dhikr).map {
                StoryItem(kind: .dhikr, text: $0.text, source: $0.source ?? "")
            }
        case .dua:
            return Adhkar.duas.map { StoryItem(kind: .dua, text: $0.text, source: $0.source ?? "") }
        case .ayah:
            return QuranCards.all.map { StoryItem(kind: .ayah, text: $0.text, source: $0.ref) }
        case .tafsir:
            guard !Lang.en else { return [] }      // the tafsir is Arabic
            return QuranCards.all.compactMap { a in
                a.tafsir.map { StoryItem(kind: .tafsir, text: a.text, source: a.ref, note: $0, noteSource: "التفسير الميسّر") }
            }
        case .hadith:
            return allMotivation.filter(isHadith).map { StoryItem(kind: .hadith, text: "«\($0.text)»", source: $0.source ?? "") }
        }
    }

    /// "البقرة ٤٥" → "سورة البقرة — آية ٤٥".
    static func ayahRef(_ s: String) -> String {
        guard let sp = s.lastIndex(of: " ") else { return s }
        let surah = s[..<sp], num = s[s.index(after: sp)...]
        let multi = num.contains("-")
        return "سورة \(surah) — \(multi ? "آيات" : "آية") \(num)"
    }

    static var kinds: [StoryItem.Kind] { Lang.en ? [.dhikr, .dua, .ayah, .hadith] : [.dhikr, .dua, .ayah, .tafsir, .hadith] }

    /// Picks a card that fits the moment, never repeating recent ones.
    /// `only` limits it to one type; otherwise the time of day / Friday tilts the choice.
    static func pick(only: StoryItem.Kind?, engine: PrayerEngine?) -> StoryItem {
        let kind: StoryItem.Kind = only ?? {
            let hour = Calendar.current.component(.hour, from: Date())
            var bag = kinds
            if (4...11).contains(hour) || (15...19).contains(hour) { bag += [.dhikr] }   // morning / evening adhkar time
            if engine?.isFriday == true { bag += [.ayah, .hadith] }
            if !Lang.en { bag += [.tafsir] }
            return bag.randomElement()!
        }()
        let pool = (items(kind).isEmpty ? items(.dhikr) : items(kind))
        let chosen = rotator.pick(pool.map { Msg($0.text, $0.source) })
        return tidy(pool.first { $0.text == chosen.text && $0.source == (chosen.source ?? "") } ?? pool[0])
    }

    /// Breaks a long dhikr/du'a at its first comma so it sits nicely on two lines.
    static func tidy(_ item: StoryItem) -> StoryItem {
        guard !item.isQuran, item.text.count > 24, let r = item.text.range(of: "، ") else { return item }
        var out = item
        out = StoryItem(kind: item.kind, text: item.text.replacingCharacters(in: r, with: "،\n"), source: item.source,
                        note: item.note, noteSource: item.noteSource, notch: item.notch)
        return out
    }

    /// One card for today (same all day): rotates through dhikr, du'a and verses by date.
    static func today() -> StoryItem {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let k: StoryItem.Kind = [.dhikr, .ayah, .dua, .dhikr, .hadith][day % 5]
        let pool = items(k).isEmpty ? items(.dhikr) : items(k)
        return tidy(pool[(day / 5) % pool.count])
    }

    /// The dhikr / du'a that just showed in the notch, as a card.
    static func fromNotch(_ m: Msg, palestine: Bool) -> StoryItem {
        let isDua = palestine || m.text.hasPrefix("اللهم") || m.text.hasPrefix("ربّ") || m.text.hasPrefix("ربنا") || m.text.hasPrefix("ربِّ")
        return tidy(StoryItem(kind: isDua ? .dua : .dhikr, text: m.text, source: m.source ?? ""))
    }
}

/// What the small notch at the top of the card says.
enum StoryNotchLabel: String, CaseIterable {
    case next, hijri, kind, none
    var title: String {
        switch self {
        case .next: return tr("الصلاة الجاية")
        case .hijri: return tr("التاريخ الهجري")
        case .kind: return tr("نوع الكارت")
        case .none: return tr("فاضية")
        }
    }
    static var saved: StoryNotchLabel {
        get { StoryNotchLabel(rawValue: UserDefaults.standard.string(forKey: "story.notchLabel") ?? "") ?? .next }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "story.notchLabel") }
    }
    func text(for item: StoryItem, engine: PrayerEngine?) -> String {
        switch self {
        case .next:
            guard let e = engine else { return "" }
            let n = e.next
            return trf("%@ بعد %@", n.prayer.arabic(friday: e.isFriday), AR.countdown(n.time.timeIntervalSinceNow))
        case .hijri: return Hijri.string(Date(), adjust: engine?.settings.hijriAdjust ?? 0)
        case .kind: return item.title
        case .none: return ""
        }
    }
}

// MARK: - Sharing actions

enum StoryExport {
    @MainActor static func image(_ item: StoryItem, post: Bool) -> NSImage? {
        let r = ImageRenderer(content: StoryCard(item: item, post: post))
        r.scale = 2
        return r.nsImage
    }

    static func png(_ img: NSImage) -> Data? {
        guard let tiff = img.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    private static var stamp: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.string(from: Date())
    }

    /// Temporary file (for AirDrop).
    static func tempFile(_ img: NSImage, post: Bool) -> URL? {
        guard let data = png(img) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AZ-Itqan-\(post ? "post" : "story")-\(stamp).png")
        return (try? data.write(to: url)) != nil ? url : nil
    }

    /// Saves to Downloads and shows it in Finder.
    @discardableResult
    static func save(_ img: NSImage, post: Bool, reveal: Bool = true) -> URL? {
        guard let data = png(img),
              let dl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return nil }
        let url = dl.appendingPathComponent("AZ-Itqan-\(post ? "post" : "story")-\(stamp).png")
        guard (try? data.write(to: url)) != nil else { return nil }
        if reveal { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        return url
    }

    static func copy(_ img: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
    }

    @discardableResult
    static func airDrop(_ img: NSImage, post: Bool) -> Bool {
        guard let url = tempFile(img, post: post), let s = NSSharingService(named: .sendViaAirDrop),
              s.canPerform(withItems: [url]) else { return false }
        s.perform(withItems: [url])
        return true
    }

    /// Opens the WhatsApp app (or WhatsApp Web).
    static func openWhatsApp() {
        for id in ["net.whatsapp.WhatsApp", "desktop.WhatsApp"] {
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: app, configuration: .init()); return
            }
        }
        if let u = URL(string: "https://web.whatsapp.com") { NSWorkspace.shared.open(u) }
    }

    static func openInstagram() {
        if let u = URL(string: "https://www.instagram.com/") { NSWorkspace.shared.open(u) }
    }
}

// MARK: - Share window

final class StoryShareModel: ObservableObject {
    @Published var item: StoryItem
    @Published var only: StoryItem.Kind? = nil { didSet { shuffle() } }
    @Published var label: StoryNotchLabel = .saved { didSet { StoryNotchLabel.saved = label; refreshLabel() } }
    @Published var status: String = ""
    weak var engine: PrayerEngine?

    init(engine: PrayerEngine?) {
        self.engine = engine
        item = StoryPool.pick(only: nil, engine: engine)
        refreshLabel()
    }
    func shuffle() { item = StoryPool.pick(only: only, engine: engine); refreshLabel() }
    func set(_ it: StoryItem) { item = it; refreshLabel() }
    func refreshLabel() { item.notch = label.text(for: item, engine: engine) }
}

struct StoryShareView: View {
    @ObservedObject var model: StoryShareModel
    var body: some View {
        ZStack {
            AZ.deepGradient.ignoresSafeArea()
            HStack(alignment: .top, spacing: 22) {
                StoryCard(item: model.item)
                    .scaleEffect(0.5, anchor: .topLeading)
                    .frame(width: 270, height: 480, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 8)

                VStack(alignment: .leading, spacing: 14) {
                    Text(tr("شارك ستوري")).font(AZFont.ui(19, .bold)).foregroundColor(.white)
                    Text(tr("كل مرة بيطلع كارت جديد… ذِكر أو دعاء أو آية أو حديث"))
                        .font(AZFont.ui(11.5)).foregroundColor(AZ.muted).fixedSize(horizontal: false, vertical: true)

                    label(tr("النوع"))
                    chips([(tr("متنوّع"), nil)] + StoryPool.kinds.map { (StoryItem(kind: $0, text: "", source: "").title, $0) },
                          selected: model.only) { model.only = $0 }

                    label(tr("المكتوب في النوتش"))
                    chips(StoryNotchLabel.allCases.map { ($0.title, $0) }, selected: model.label) { model.label = $0 }

                    Button { withAnimation(.easeInOut(duration: 0.2)) { model.shuffle() } } label: {
                        Label(tr("غيّر الكارت"), systemImage: "arrow.triangle.2.circlepath")
                            .font(AZFont.ui(12.5, .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.08)))
                    }.buttonStyle(.plain)

                    Divider().overlay(AZ.line)

                    HStack(spacing: 8) {
                        action(tr("ستوري إنستجرام"), "camera.fill", primary: true) { instaStory() }
                        action(tr("حالة واتساب"), "circle.dashed", primary: true) { whatsapp() }
                    }
                    HStack(spacing: 8) {
                        action(tr("حفظ"), "arrow.down.circle") { save() }
                        action(tr("نسخ"), "doc.on.doc") { copy() }
                    }

                    if !model.status.isEmpty {
                        Text(model.status).font(AZFont.ui(11.5)).foregroundColor(AZ.lime)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 300)
            }
            .padding(22)
        }
        .frame(width: 636, height: 524)
    }

    private func chips<T: Equatable>(_ options: [(String, T)], selected: T, _ pick: @escaping (T) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                let on = o.1 == selected
                Button { withAnimation(.easeInOut(duration: 0.15)) { pick(o.1) } } label: {
                    Text(o.0).font(AZFont.ui(11, on ? .bold : .medium)).lineLimit(1).minimumScaleFactor(0.75)
                        .foregroundColor(on ? AZ.navy : AZ.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                        .background(Capsule().fill(on ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.clear)))
                }.buttonStyle(.plain)
            }
        }
        .padding(2).background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private func label(_ s: String) -> some View {
        Text(s).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.muted)
    }

    private func action(_ title: String, _ icon: String, primary: Bool = false, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(AZFont.ui(12, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundColor(primary ? AZ.navy : .white)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(primary ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.white.opacity(0.08))))
        }.buttonStyle(.plain)
    }

    // Instagram/WhatsApp can't receive a story from a Mac app, so the image goes to the phone (AirDrop) or the clipboard.
    /// Instagram and WhatsApp only accept a story/status from the phone app, so the card goes to the iPhone by AirDrop;
    /// there, Share → Instagram → Stories / WhatsApp → My Status opens the story composer directly.
    @MainActor private func instaStory() { toPhone(tr("على الموبايل: افتح الصورة ← مشاركة ← Instagram ← Stories")) }
    @MainActor private func whatsapp() { toPhone(tr("على الموبايل: افتح الصورة ← مشاركة ← WhatsApp ← حالتي (My Status)")) }

    @MainActor private func toPhone(_ howTo: String) {
        guard let img = StoryExport.image(model.item, post: false) else { return }
        if StoryExport.airDrop(img, post: false) {
            model.status = tr("اختار موبايلك من AirDrop.") + "\n" + howTo
        } else {
            StoryExport.copy(img)
            StoryExport.save(img, post: false, reveal: false)
            model.status = tr("AirDrop مش شغّال (فعّل البلوتوث والواي فاي). الصورة اتحفظت في Downloads واتنسخت… ابعتها لموبايلك.") + "\n" + howTo
        }
    }
    @MainActor private func save() {
        guard let img = StoryExport.image(model.item, post: false) else { return }
        model.status = StoryExport.save(img, post: false) != nil ? tr("اتحفظت في Downloads") : tr("ماقدرتش أحفظ الصورة")
    }
    @MainActor private func copy() {
        guard let img = StoryExport.image(model.item, post: false) else { return }
        StoryExport.copy(img)
        model.status = tr("اتنسخت… الزقها في أي حتة (⌘V)")
    }
}

final class StoryShareWindowController {
    private var window: NSWindow?
    private var model: StoryShareModel?
    weak var engine: PrayerEngine?

    func show(_ start: StoryItem? = nil) {
        if window == nil {
            let m = StoryShareModel(engine: engine)
            model = m
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 636, height: 524),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.appearance = NSAppearance(named: .darkAqua)
            w.animationBehavior = .none
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: StoryShareView(model: m).environment(\.layoutDirection, Lang.dir))
            w.center()
            window = w
        } else {
            model?.status = ""
            model?.shuffle()
        }
        if let start { model?.set(start) }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
