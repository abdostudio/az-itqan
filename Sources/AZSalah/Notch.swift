import SwiftUI
import AppKit

enum AZFont {
    static func thuluth(_ size: CGFloat) -> Font {
        NSFont(name: "Diwan Thuluth", size: size) != nil ? .custom("Diwan Thuluth", size: size) : .system(size: size, weight: .bold)
    }
    static func naskh(_ size: CGFloat) -> Font {
        NSFont(name: "Mishafi", size: size) != nil ? .custom("Mishafi", size: size) : .system(size: size)
    }
    /// Quran text: Amiri Quran (bundled, OFL) draws the Uthmani marks correctly.
    static func quran(_ size: CGFloat) -> Font {
        registerBundled()
        return NSFont(name: "Amiri Quran", size: size) != nil ? .custom("Amiri Quran", size: size) : naskh(size)
    }
    private static var registered = false
    static func registerBundled() {
        guard !registered else { return }
        registered = true
        let candidates = [Bundle.main.resourceURL?.appendingPathComponent("fonts/AmiriQuran.ttf"),
                          URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/fonts/AmiriQuran.ttf")]
        for case let u? in candidates where FileManager.default.fileExists(atPath: u.path) {
            CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil); break
        }
    }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

enum NotchAnim {
    static let open = Animation.spring(response: 0.34, dampingFraction: 0.78)
    static let close = Animation.spring(response: 0.28, dampingFraction: 0.92)
    static let peek = Animation.spring(response: 0.38, dampingFraction: 0.82)
}

// MARK: - Model (one per screen)

final class NotchModel: ObservableObject {
    enum Alert: Equatable {
        case pre(Prayer, Date)
        case peek(Msg, palestine: Bool)
        case fasting([String], String)
        case deferred(Prayer)
        case info(String, String)
        case ramadan(String, String)
        case adhkar(MorningEvening.Kind, Msg)
        case wird(Msg)
        case update(String, String)
        case sadaqa(Msg)
        case rahim(UUID?, Msg, String)
        case nafl(Nafl, Msg)
        case naflCheck(Nafl)
        case zakat(String, String)
        case share(String, String)
    }

    @Published var expanded = false
    @Published var alert: Alert?
    @Published var tasbih = 0
    @Published var palestineMsg = MessagePicker.palestineRotator.pick(Palestine.items)
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 32
    @Published var hasNotch = true
    /// Free-floating island (rounded on every side, draggable).
    @Published var floating = false
    /// Proportional scale of the whole island (floating mode only).
    @Published var scale: CGFloat = 1
    /// Dhikr that stays visible under the notch while idle (rotates on a timer).
    @Published var ambient: Ambient?
    /// True while the cursor is right under the strip: it steps aside so whatever is below stays usable.
    @Published var dodging = false
    /// The strip as it should be drawn right now.
    var shownAmbient: Ambient? { dodging && !floating ? nil : ambient }
    /// A prayer skipped with "emergency" and not yet confirmed.
    @Published var owedPrayer: Prayer?
    /// When set, the expanded notch becomes a one-dhikr-at-a-time reader.
    @Published var reader: MorningEvening.Kind?
    /// Expanded notch section: 0 اليوم · 1 التقرير · 2 العطاء
    @Published var tab = 0
    var onConfirmOwed: (() -> Void)?
    var onOpenRamadan: (() -> Void)?
    var onNaflCommit: ((Nafl) -> Void)?
    var onOpenAdhkar: ((MorningEvening.Kind) -> Void)?

    struct Ambient: Equatable {
        let msg: Msg
        let palestine: Bool
        var owed = false
        /// Text width, so the strip grows/shrinks to fit each dhikr.
        let textWidth: CGFloat
        static let fontSize: CGFloat = 11.5
        init(msg: Msg, palestine: Bool, owed: Bool = false) {
            self.msg = msg; self.palestine = palestine; self.owed = owed
            let font = NSFont.systemFont(ofSize: Self.fontSize, weight: .semibold)
            textWidth = ceil((msg.text as NSString).size(withAttributes: [.font: font]).width) + (palestine ? 22 : 0) + (owed ? 18 : 0)
        }
    }

    var onLockNow: ((Prayer) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onShare: ((StoryItem?) -> Void)?

    private var alertToken = 0

    func show(_ a: Alert, for seconds: TimeInterval?) {
        alertToken += 1
        let token = alertToken
        withAnimation(NotchAnim.peek) { alert = a }
        if let seconds {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                guard let self, self.alertToken == token else { return }
                self.dismissAlert()
            }
        }
    }

    /// Shows the adhkar reader inside the notch.
    func openReader(_ k: MorningEvening.Kind) {
        AdhkarSession.shared.start(k)
        alert = nil
        withAnimation(NotchAnim.open) { reader = k; expanded = true }
    }

    func dismissAlert() {
        guard alert != nil else { return }
        withAnimation(NotchAnim.close) { alert = nil }
    }

    var isPeek: Bool { if case .peek = alert { return true }; return false }

    // Layout sizes — constant per state so content never reflows while animating.
    static let side: CGFloat = 66
    /// Idle look: 0 fuel line under the camera · 1 dot · 2 small text · 3 full.
    @Published var idleLevel = 3
    var wings: Bool { get { idleLevel == 3 } set { idleLevel = newValue ? 3 : 0 } }
    var wingFactor: CGFloat {
        get { [0, 0.3, 0.73, 1][idleLevel] }
        set { idleLevel = newValue >= 0.99 ? 3 : newValue > 0.6 ? 2 : newValue > 0.01 ? 1 : 0 }
    }
    var onCamera: Bool { hasNotch && !floating }
    var effectiveLevel: Int { onCamera ? idleLevel : 3 }
    var slimNow: Bool { effectiveLevel == 0 }
    static let levelWing: [CGFloat] = [0, 20, 48, 66]
    /// A few points under the camera for the "fuel" line (the camera cutout itself shows no pixels).
    var fuelBar: CGFloat { onCamera ? 6 : 0 }
    var compactSize: CGSize { CGSize(width: notchWidth + 2 * Self.levelWing[effectiveLevel], height: notchHeight + fuelBar) }
    var isSadaqa: Bool { if case .sadaqa = alert { return true }; return false }
    var fastingText: String? { if case .fasting(let t, _) = alert { return t.joined(separator: " · ") + tr(" — نوِيت؟") }; return nil }
    /// Fasting reminder: a slim one-line strip like the dhikr, fitted to its text.
    var fastingSize: CGSize {
        let w = ((fastingText ?? "") as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12.5, weight: .semibold)]).width
        return CGSize(width: min(max(notchWidth + 40, w + 64), 560), height: notchHeight + 26)
    }
    var isRahim: Bool { if case .rahim = alert { return true }; return false }
    var sadaqaSize: CGSize { CGSize(width: max(notchWidth + 2 * 150, 500), height: notchHeight + 128) }
    var peekSize: CGSize { CGSize(width: max(notchWidth + 2 * Self.side, 480), height: notchHeight + 52) }
    var alertSize: CGSize { CGSize(width: max(notchWidth + 2 * 110, 460), height: notchHeight + 88) }
    /// Slim strip under the notch for the always-on dhikr: one line, nothing else.
    /// Slim one-line strip under the notch, fitted to the text.
    var ambientSize: CGSize {
        let fitted = (ambient?.textWidth ?? 0) + 44
        return CGSize(width: min(max(notchWidth + 40, fitted), 520), height: notchHeight + 24)
    }
    var expandedSize: CGSize { CGSize(width: max(notchWidth + 2 * 140, 520), height: notchHeight + (StoryFeature.onMac ? 414 : 318)) }
    var currentSize: CGSize {
        if expanded { return expandedSize }
        if alert != nil { return isPeek ? peekSize : fastingText != nil ? fastingSize : (isSadaqa || isRahim ? sadaqaSize : alertSize) }
        return shownAmbient != nil ? ambientSize : compactSize
    }
}

// MARK: - Hosting view that only catches clicks inside the visible notch

final class NotchHostingView<V: View>: NSHostingView<V> {
    var activeSize: () -> CGSize = { .zero }
    var canDrag: () -> Bool = { false }
    var onClick: () -> Void = {}
    var onDragEnd: () -> Void = {}
    private var dragStart: NSPoint?
    private var originStart: NSPoint?
    private var dragging = false

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with e: NSEvent) {
        guard canDrag(), let w = window else { return super.mouseDown(with: e) }
        dragStart = w.convertPoint(toScreen: e.locationInWindow)
        originStart = w.frame.origin
        dragging = false
    }

    override func mouseDragged(with e: NSEvent) {
        guard let start = dragStart, let o = originStart, let w = window else { return super.mouseDragged(with: e) }
        let p = w.convertPoint(toScreen: e.locationInWindow)
        let dx = p.x - start.x, dy = p.y - start.y
        if !dragging && hypot(dx, dy) < 3 { return }
        dragging = true
        w.setFrameOrigin(NSPoint(x: o.x + dx, y: o.y + dy))
    }

    override func mouseUp(with e: NSEvent) {
        guard dragStart != nil else { return super.mouseUp(with: e) }
        dragStart = nil
        if dragging { onDragEnd() } else { onClick() }
        dragging = false
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        let s = activeSize()
        let x = (bounds.width - s.width) / 2
        let y = isFlipped ? 0 : bounds.height - s.height
        return NSRect(x: x, y: y, width: s.width, height: s.height).contains(local) ? super.hitTest(point) : nil
    }
}

// MARK: - One panel on one screen

/// Panel that can take keyboard focus (zakat fields) without activating the app.
final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class NotchPanel {
    let model = NotchModel()
    let screenID: CGDirectDisplayID
    private(set) var screen: NSScreen
    private let panel: NSPanel
    private var collapseWork: DispatchWorkItem?
    private var openWork: DispatchWorkItem?
    static let baseCanvas = CGSize(width: 640, height: 480)
    /// Room for the island at its current scale.
    private var canvas: CGSize {
        let s = max(1, model.scale)
        return CGSize(width: Self.baseCanvas.width * s, height: Self.baseCanvas.height * s)
    }

    init(screen: NSScreen, engine: PrayerEngine) {
        self.screen = screen
        screenID = screen.displayID
        let p = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.becomesKeyOnlyIfNeeded = true
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.acceptsMouseMovedEvents = true // so leaving the island is noticed instantly
        p.isMovable = false
        let root = NotchRootView(model: model, engine: engine).environment(\.layoutDirection, Lang.dir)
        let host = NotchHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.baseCanvas)
        host.autoresizingMask = [.width, .height]
        host.sizingOptions = []
        p.animationBehavior = .none
        panel = p
        host.activeSize = { [weak model] in
            guard let m = model else { return .zero }
            return CGSize(width: m.currentSize.width * m.scale, height: m.currentSize.height * m.scale)
        }
        // Floating island: drag it anywhere; a click (no drag) opens it.
        host.canDrag = { [weak model] in
            guard let m = model else { return false }
            return m.floating && !m.expanded && (m.alert == nil || m.isPeek)
        }
        host.onClick = { [weak self] in
            guard let self else { return }
            self.model.alert = nil
            withAnimation(NotchAnim.open) { self.model.expanded = true }
            self.syncMouse()
        }
        host.onDragEnd = { [weak self] in self?.savePosition() }
        p.contentView = host
        place(on: screen)
        p.orderFrontRegardless()
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: p, queue: .main) { [weak self] _ in
            self?.savePosition()
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: p, queue: .main) { [weak self] _ in
            guard let self, self.model.expanded else { return }
            self.track(NSEvent.mouseLocation)
        }
    }

    // MARK: floating position (saved per screen as the island's top-centre point)

    private var posKey: String { "island.pos.\(screenID)" }
    static func resetPositions() {
        for k in UserDefaults.standard.dictionaryRepresentation().keys where k.hasPrefix("island.pos.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func savePosition() {
        guard model.floating else { return }
        UserDefaults.standard.set([panel.frame.midX, panel.frame.maxY], forKey: posKey)
    }

    func place(on s: NSScreen) {
        screen = s
        model.floating = AppSettings.shared.islandFloating
        model.scale = model.floating ? CGFloat(AppSettings.shared.islandScale) : 1
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        if model.floating {
            model.notchWidth = 22
            model.notchHeight = 30
            model.hasNotch = false
            var top = NSPoint(x: s.frame.midX, y: s.visibleFrame.maxY - 14)
            if let saved = UserDefaults.standard.array(forKey: posKey) as? [Double], saved.count == 2 {
                top = NSPoint(x: saved[0], y: saved[1])
            }
            // Only pull it back if the saved spot is off every screen (e.g. a display was unplugged).
            if !NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -2, dy: -2).contains(top) }) {
                top = NSPoint(x: s.frame.midX, y: s.visibleFrame.maxY - 14)
            }
            panel.setFrame(NSRect(x: top.x - canvas.width / 2, y: top.y - canvas.height,
                                  width: canvas.width, height: canvas.height), display: true)
            return
        }
        if s.safeAreaInsets.top > 0 {
            let left = s.auxiliaryTopLeftArea?.width ?? 0
            let right = s.auxiliaryTopRightArea?.width ?? 0
            model.notchWidth = max(120, s.frame.width - left - right)
            model.notchHeight = s.safeAreaInsets.top
            model.hasNotch = true
        } else {
            // No notch: a slim island hanging from the menu bar.
            model.notchWidth = 64
            model.notchHeight = max(24, s.frame.maxY - s.visibleFrame.maxY)
            model.hasNotch = false
        }
        let origin = NSPoint(x: s.frame.midX - canvas.width / 2, y: s.frame.maxY - canvas.height)
        panel.setFrame(NSRect(origin: origin, size: canvas), display: true)
    }

    func close() { panel.orderOut(nil) }

    /// The island hangs from the top-centre of the panel (which sits under the notch, or wherever it was dragged).
    private func rect(_ logical: CGSize, slack: CGFloat) -> NSRect {
        let size = CGSize(width: logical.width * model.scale, height: logical.height * model.scale)
        let f = panel.frame
        return NSRect(x: f.midX - size.width / 2 - slack, y: f.maxY - size.height - slack,
                      width: size.width + 2 * slack, height: size.height + slack + 2)
    }

    /// Called on every mouse move (event driven, so it reacts instantly).
    func track(_ m: NSPoint) {
        if model.expanded {
            // While typing in the zakat calculator, don't fold away when the mouse drifts.
            if panel.isKeyWindow && model.tab == 2 {
                collapseWork?.cancel(); collapseWork = nil
                syncMouse(); return
            }
            if rect(model.expandedSize, slack: 10).contains(m) {
                collapseWork?.cancel(); collapseWork = nil
            } else if collapseWork == nil {
                let w = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    withAnimation(NotchAnim.close) { self.model.expanded = false }
                    self.collapseWork = nil
                    self.syncMouse()
                }
                collapseWork = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: w)
            }
        } else {
            dodge(m)
            // With the dhikr strip showing, only the notch itself opens the island — the strip just steps aside.
            let stripOn = model.ambient != nil && model.alert == nil && !model.floating
            let hot = rect(stripOn ? model.compactSize : model.currentSize, slack: 1)
            let blocking = model.alert != nil && !model.isPeek
            // A pressed mouse button means the user is dragging the floating island — don't pop it open.
            if hot.contains(m) && !blocking && NSEvent.pressedMouseButtons == 0 && !model.floating {
                if openWork == nil {
                    let w = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        self.openWork = nil
                        guard self.rect(self.model.currentSize, slack: 1).contains(NSEvent.mouseLocation) else { return }
                        self.model.alert = nil
                        withAnimation(NotchAnim.open) { self.model.expanded = true }
                        self.syncMouse()
                    }
                    openWork = w
                    // tiny intent delay so passing the cursor through the menu bar doesn't pop it open
                    DispatchQueue.main.asyncAfter(deadline: .now() + (model.floating ? 0.3 : 0.07), execute: w)
                }
            } else {
                openWork?.cancel(); openWork = nil
            }
        }
        syncMouse()
    }

    private var undodgeWork: DispatchWorkItem?

    /// The idle strip hangs a little below the menu bar and can cover an app's toolbar.
    /// When the cursor comes close under it, fade it away and let clicks through; bring it back once the cursor leaves.
    private func dodge(_ m: NSPoint) {
        guard model.ambient != nil, model.alert == nil, !model.floating else {
            if model.dodging { model.dodging = false }
            return
        }
        let r = rect(model.ambientSize, slack: 0)
        let below = r.height - model.notchHeight          // the part hanging under the menu bar
        let zone = NSRect(x: r.minX - 24, y: r.minY - 36, width: r.width + 48, height: below + 36)
        if zone.contains(m) {
            undodgeWork?.cancel(); undodgeWork = nil
            if !model.dodging { withAnimation(.easeOut(duration: 0.18)) { model.dodging = true } }
        } else if model.dodging && !zone.insetBy(dx: -40, dy: -40).contains(m) && undodgeWork == nil {
            let w = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.undodgeWork = nil
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { self.model.dodging = false }
                self.syncMouse()
            }
            undodgeWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: w)
        }
    }

    /// The panel is a big transparent canvas, so it only accepts clicks while the cursor is
    /// actually over the visible island. Everywhere else clicks go straight to the windows below.
    func syncMouse() {
        // The floating island is always grabbable, even when it only shows the countdown.
        let visible = model.expanded || model.alert != nil || model.shownAmbient != nil || model.floating
        let slack: CGFloat = model.expanded ? 10 : 2
        let overIsland = rect(model.currentSize, slack: slack).contains(NSEvent.mouseLocation)
        let interactive = visible && overIsland
        if panel.ignoresMouseEvents == interactive { panel.ignoresMouseEvents = !interactive }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

// MARK: - Controller for all screens

final class NotchController {
    private let engine: PrayerEngine
    private let settings: AppSettings
    private(set) var panels: [NotchPanel] = []
    private var monitors: [Any] = []
    private var fallback: Timer?
    private var wingsTimer: Timer?

    /// Idle width from the settings slider; opens fully in the last 15 minutes before the adhan.
    /// Per-second UI updates are only needed while the island is open or an alert shows.
    private func updateLive() {
        engine.liveSeconds = panels.contains { $0.model.expanded || $0.model.alert != nil }
    }

    func updateWings() {
        let remaining = engine.next.time.timeIntervalSince(Date())
        let lvl = remaining <= 15 * 60 ? 3 : min(3, max(0, settings.idleLevel))
        for p in panels where p.model.idleLevel != lvl {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { p.model.idleLevel = lvl }
        }
    }

    var onLockNow: ((Prayer) -> Void)? { didSet { panels.forEach { $0.model.onLockNow = onLockNow } } }
    var onOpenSettings: (() -> Void)? { didSet { panels.forEach { $0.model.onOpenSettings = onOpenSettings } } }
    var onShare: ((StoryItem?) -> Void)? { didSet { panels.forEach { $0.model.onShare = onShare } } }
    var onConfirmOwed: (() -> Void)? { didSet { panels.forEach { $0.model.onConfirmOwed = onConfirmOwed } } }
    var onOpenRamadan: (() -> Void)? { didSet { panels.forEach { $0.model.onOpenRamadan = onOpenRamadan } } }
    var onNaflCommit: ((Nafl) -> Void)? { didSet { panels.forEach { $0.model.onNaflCommit = onNaflCommit } } }
    var onOpenAdhkar: ((MorningEvening.Kind) -> Void)? { didSet { panels.forEach { $0.model.onOpenAdhkar = onOpenAdhkar } } }
    var owedPrayer: Prayer? { didSet { panels.forEach { $0.model.owedPrayer = owedPrayer } } }

    init(engine: PrayerEngine, settings: AppSettings) { self.engine = engine; self.settings = settings }

    func start() {
        rebuild()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.rebuild() }
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.track() }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { e in handler(e); return e }) { monitors.append(l) }
        // Safety net in case a move event is missed.
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.track() }
        RunLoop.main.add(t, forMode: .common)
        fallback = t
        let wt = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.updateWings() }
        RunLoop.main.add(wt, forMode: .common)
        wingsTimer = wt
        updateWings()
    }

    func rebuild() {
        let wanted = targetScreens()
        let ids = Set(wanted.map(\.displayID))
        panels.filter { !ids.contains($0.screenID) }.forEach { $0.close() }
        panels.removeAll { !ids.contains($0.screenID) }
        for s in wanted {
            if let p = panels.first(where: { $0.screenID == s.displayID }) {
                p.place(on: s)
            } else {
                let p = NotchPanel(screen: s, engine: engine)
                p.model.ambient = ambient
                p.model.owedPrayer = owedPrayer
                p.model.onConfirmOwed = onConfirmOwed
                p.model.onOpenRamadan = onOpenRamadan
                p.model.onNaflCommit = onNaflCommit
                p.model.onOpenAdhkar = onOpenAdhkar
                p.model.onLockNow = onLockNow
                p.model.onOpenSettings = onOpenSettings
                p.model.onShare = onShare
                panels.append(p)
            }
        }
    }

    private func targetScreens() -> [NSScreen] {
        let all = NSScreen.screens
        switch settings.displayMode {
        case "notch":
            if let n = all.first(where: { $0.safeAreaInsets.top > 0 }) { return [n] }
            return Array(all.prefix(1))
        case "main":
            return Array(all.prefix(1)) // the screen with the menu bar
        default:
            return all
        }
    }

    private func track() {
        updateLive()
        let m = NSEvent.mouseLocation
        // Cheap early-out: nothing open and the cursor is nowhere near the top of its screen.
        let idle = panels.allSatisfy { !$0.model.expanded && $0.model.alert == nil && $0.model.ambient == nil && !$0.model.floating }
        if idle, let s = NSScreen.screens.first(where: { NSMouseInRect(m, $0.frame, false) }), m.y < s.frame.maxY - 120 { return }
        for p in panels { p.track(m) }
    }

    func show(_ a: NotchModel.Alert, for seconds: TimeInterval?) { panels.forEach { $0.model.show(a, for: seconds) } }

    /// Current always-on dhikr (nil hides it); applied to every screen and to screens added later.
    var ambient: NotchModel.Ambient? {
        didSet {
            // Springy resize to the new text width (same bounce as opening).
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { panels.forEach { $0.model.ambient = ambient } }
        }
    }
    func dismissAlert() { panels.forEach { $0.model.dismissAlert() } }
}

// MARK: - Views

struct NotchRootView: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var engine: PrayerEngine

    var body: some View {
        let size = model.currentSize
        let radius: CGFloat = model.expanded ? 26 : (model.alert != nil ? 20 : 11)
        let rich = model.expanded || model.alert != nil || model.shownAmbient != nil
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Color.black
                if model.shownAmbient != nil && !model.expanded && model.alert == nil {
                    // Pure black through the notch and a bit below it, then easing into AZ navy,
                    // so the strip reads as one piece with the notch — no visible seam.
                    let n = model.notchHeight / max(size.height, 1)
                    LinearGradient(stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: min(0.9, n + 0.04)),
                        .init(color: AZ.navy, location: min(0.95, n + 0.28)),
                        .init(color: AZ.indigo.opacity(0.85), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(colors: [Color.black, AZ.navy, AZ.indigo.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                        .opacity(rich ? 1 : 0)
                }
                content
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .compositingGroup()
            .clipShape(model.floating ? AnyShape(RoundedRectangle(cornerRadius: radius + 5, style: .continuous))
                                      : AnyShape(NotchShape(radius: radius)))

            .contentShape(model.floating ? AnyShape(RoundedRectangle(cornerRadius: radius + 5)) : AnyShape(NotchShape(radius: radius)))
            .onTapGesture { if model.alert != nil, !model.expanded { model.dismissAlert() } }
            // Everything scales together, anchored at the top centre.
            .scaleEffect(model.scale, anchor: .top)
            .frame(width: size.width * model.scale, height: size.height * model.scale, alignment: .top)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundColor(.white)
    }

    private var fadeIn: AnyTransition {
        .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.16)),
                    removal: .opacity.animation(.easeOut(duration: 0.08)))
    }

    @ViewBuilder private var content: some View {
        if model.expanded, let k = model.reader {
            AdhkarNotchReader(model: model, session: AdhkarSession.shared, kind: k)
                .frame(width: model.expandedSize.width, height: model.expandedSize.height, alignment: .top)
                .transition(fadeIn)
        } else if model.expanded {
            ExpandedNotch(model: model, engine: engine)
                .frame(width: model.expandedSize.width, height: model.expandedSize.height, alignment: .top)
                .transition(fadeIn)
        } else if let a = model.alert {
            if case .peek(let msg, let pal) = a {
                PeekNotch(model: model, msg: msg, palestine: pal)
                    .frame(width: model.peekSize.width, height: model.peekSize.height, alignment: .top)
                    .transition(fadeIn)
            } else if let t = model.fastingText {
                FastingSlim(model: model, text: t)
                    .frame(width: model.fastingSize.width, height: model.fastingSize.height, alignment: .top)
                    .transition(fadeIn)
            } else if case .rahim(let id, let m, let idea) = a {
                RahimNotch(model: model, personID: id, msg: m, idea: idea)
                    .frame(width: model.sadaqaSize.width, height: model.sadaqaSize.height, alignment: .top)
                    .transition(fadeIn)
            } else if case .sadaqa(let m) = a {
                SadaqaNotch(model: model, msg: m, flow: SadaqaFlow.shared)
                    .frame(width: model.sadaqaSize.width, height: model.sadaqaSize.height, alignment: .top)
                    .transition(fadeIn)
            } else {
                AlertNotch(model: model, engine: engine, alert: a)
                    .frame(width: model.alertSize.width, height: model.alertSize.height, alignment: .top)
                    .transition(fadeIn)
            }
        } else if let amb = model.shownAmbient {
            VStack(spacing: 0) {
                if model.floating {
                    CompactNotch(model: model, engine: engine).frame(width: model.compactSize.width, height: model.notchHeight)
                } else {
                    Color.clear.frame(height: model.notchHeight)
                }
                AmbientLine(ambient: amb).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay(alignment: .bottom) {
                if amb.palestine { PalestineEdge().padding(.horizontal, 18).transition(.opacity) }
            }
            .frame(width: model.ambientSize.width, height: model.ambientSize.height, alignment: .top)
            .transition(fadeIn)
        } else {
            CompactNotch(model: model, engine: engine)
                .frame(width: model.compactSize.width, height: model.compactSize.height)
                .transition(fadeIn)
        }
    }
}

struct CompactNotch: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var engine: PrayerEngine

    var body: some View {
        let next = engine.next
        let remaining = next.time.timeIntervalSince(engine.now)
        let soon = remaining < TimeInterval(max(1, engine.settings.preAlertMinutes) * 60)
        let lvl = model.effectiveLevel
        let w = max(0, NotchModel.levelWing[lvl] - 6)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    if lvl == 3 { AZSwoosh().fill(soon ? AZ.lime : AZ.violet).frame(width: 12, height: 8) }
                    if lvl >= 2 {
                        Text(next.prayer.arabic(friday: engine.isFriday))
                            .font(AZFont.ui(11, .semibold))
                            .foregroundColor(soon ? AZ.lime : .white)
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                    if lvl == 1 { FuelDot(fuel: engine.fuel) }
                }
                .frame(width: w)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    if lvl == 3 {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.8)
                            Circle().trim(from: 0, to: engine.progress)
                                .stroke(AZ.accentGradient, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 10, height: 10)
                    }
                    if lvl >= 2 {
                        Text(AR.countdown(remaining))
                            .font(AZFont.ui(11, .medium).monospacedDigit())
                            .foregroundColor(soon ? AZ.lime : AZ.muted)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .frame(width: w)
            }
            .padding(.horizontal, lvl > 0 ? 3 : 0)
            .frame(height: model.notchHeight)
            if model.fuelBar > 0 {
                FuelLine(fuel: engine.fuel).frame(width: max(60, model.notchWidth - 30), height: 2.5).padding(.top, 1)
            }
            Spacer(minLength: 0)
        }
    }
}

/// "Spiritual fuel": full right after you pray, drains toward the next prayer, refills when you pray again.
enum Fuel {
    static func color(_ f: Double) -> Color {
        func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
            let t = min(1, max(0, t))
            return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
        }
        let lime = (0.83, 1.0, 0.14), gold = (0.91, 0.77, 0.42), coral = (1.0, 0.54, 0.50)
        if f >= 0.6 { return mix(gold, lime, (f - 0.6) / 0.4 * 2.5) }
        if f >= 0.25 { return mix(coral, gold, (f - 0.25) / 0.35) }
        return Color(red: coral.0, green: coral.1, blue: coral.2)
    }
}

struct FuelLine: View {
    let fuel: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                if fuel < 0.12 {
                    PulsingCapsule(color: Fuel.color(fuel)).frame(width: max(6, g.size.width * fuel))
                } else {
                    Capsule().fill(LinearGradient(colors: [Fuel.color(fuel), Fuel.color(min(1, fuel + 0.25))],
                                                  startPoint: .trailing, endPoint: .leading))
                        .frame(width: g.size.width * fuel)
                        .shadow(color: Fuel.color(fuel).opacity(0.6), radius: 2)
                }
            }
            .animation(.spring(response: 1.3, dampingFraction: 0.72), value: Int(fuel * 200))
        }
    }
}

struct FuelDot: View {
    let fuel: Double
    var body: some View {
        if fuel < 0.12 { PulsingCapsule(color: Fuel.color(fuel)).frame(width: 7, height: 7) }
        else { Circle().fill(Fuel.color(fuel)).frame(width: 7, height: 7).shadow(color: Fuel.color(fuel).opacity(0.6), radius: 2) }
    }
}

final class PulseState: ObservableObject { @Published var on = false }

/// Only exists while the tank is (nearly) empty — the one place the idle notch animates.
struct PulsingCapsule: View {
    let color: Color
    @StateObject private var pulse = PulseState()
    var body: some View {
        Capsule().fill(color)
            .opacity(pulse.on ? 0.35 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse.on = true } }
    }
}

/// Sadaqa reminder: given / a sadaqa without money / not today.
final class SadaqaFlow: ObservableObject {
    static let shared = SadaqaFlow()
    enum Stage { case main, free, skip, done }
    @Published var stage: Stage = .main
    @Published var idea = Msg("")
    @Published var ideaIndex = 0
    func reset() { stage = .main }
    func nextIdea() {
        idea = SadaqaLog.freeRotator.pick(SadaqaLog.freeIdeas)
        ideaIndex = (SadaqaLog.freeIdeas.firstIndex { $0.text == idea.text } ?? 0) + 1
    }
}

struct SadaqaNotch: View {
    @ObservedObject var model: NotchModel
    let msg: Msg
    @ObservedObject var flow: SadaqaFlow

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchHeight)
            VStack(alignment: .leading, spacing: 0) {
                switch flow.stage {
                case .main:
                    row(icon: "heart.circle.fill", tint: AZ.gold, title: tr("صدقة النهارده"), titleColor: AZ.lime, text: msg.text, source: msg.source)
                    bar {
                        pill(tr("طلّعت"), "checkmark", primary: true) {
                            SadaqaLog.shared.markGiven()
                            finish(.done)
                        }
                        pill(tr("صدقة من غير فلوس"), "sparkles", primary: false) {
                            flow.nextIdea()
                            withAnimation(.easeOut(duration: 0.2)) { flow.stage = .free }
                        }
                        Spacer(minLength: 0)
                        link(tr("مش النهارده")) { finish(.skip) }
                    }
                case .free:
                    row(icon: "face.smiling", tint: AZ.lime,
                        title: trf("صدقة من غير فلوس — فكرة %@ من %@", AR.num(flow.ideaIndex), AR.num(SadaqaLog.freeIdeas.count)),
                        titleColor: Color(hex: 0x7FA8FF), text: flow.idea.text, source: flow.idea.source)
                    bar {
                        pill(tr("هعملها"), "checkmark", primary: true) {
                            SadaqaLog.shared.markGiven()
                            finish(.done)
                        }
                        pill(tr("فكرة تانية"), "arrow.clockwise", primary: false) {
                            withAnimation(.easeOut(duration: 0.2)) { flow.nextIdea() }
                        }
                        Spacer(minLength: 0)
                        link(tr("رجوع")) { withAnimation(.easeOut(duration: 0.2)) { flow.stage = .main } }
                    }
                case .skip:
                    row(icon: "heart.fill", tint: Color(hex: 0x7FA8FF), title: nil, titleColor: .clear,
                        text: tr("ولا يهمك… ربنا يرزقك"), source: tr("ولو بنيّة صادقة. مش هنفكّرك تاني النهارده"))
                case .done:
                    row(icon: "checkmark.seal.fill", tint: AZ.lime, title: nil, titleColor: .clear,
                        text: tr("تقبّل الله منك"), source: tr("ما شاء الله… اتسجلت في تقرير العطاء"))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    private func finish(_ s: SadaqaFlow.Stage) {
        withAnimation(.easeOut(duration: 0.2)) { flow.stage = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak model] in
            if model?.isSadaqa == true { model?.dismissAlert() }
        }
    }

    private func row(icon: String, tint: Color, title: String?, titleColor: Color, text: String, source: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.14))
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(tint)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                if let title { Text(title).font(AZFont.ui(11.5, .semibold)).foregroundColor(titleColor) }
                Text(text).font(AZFont.ui(14.5, .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                if let source { Text(source).font(AZFont.ui(10.5)).foregroundColor(AZ.muted).lineLimit(1) }
            }
            Spacer(minLength: 0)
        }
    }

    private func bar<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5)
            HStack(spacing: 8) { c() }
        }
        .padding(.top, 12)
    }

    private func pill(_ title: String, _ icon: String, primary: Bool, _ action: @escaping () -> Void) -> some View {
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

    private func link(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(AZFont.ui(11)).foregroundColor(AZ.muted) }.buttonStyle(.plain)
    }
}

/// The always-visible dhikr line; cross-fades when the text changes.
struct AmbientLine: View {
    let ambient: NotchModel.Ambient
    var body: some View {
        HStack(spacing: 7) {
            if ambient.palestine {
                PalestineFlag().frame(width: 15, height: 10)
            }
            if ambient.owed {
                Image(systemName: "clock.badge.exclamationmark").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.gold)
            }
            Text(ambient.msg.text)
                .font(.system(size: NotchModel.Ambient.fontSize, weight: .semibold))
                .foregroundColor(ambient.owed ? AZ.gold : .white)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 3)
        .id(ambient.msg.text)
        .transition(.opacity)
    }
}

/// Thin line in the Palestinian flag colours, drawn along the bottom edge of the strip.
struct PalestineEdge: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: Color(hex: 0xE4312B), location: 0.2),
            .init(color: .white.opacity(0.9), location: 0.45),
            .init(color: Color(hex: 0x149954), location: 0.8),
            .init(color: .clear, location: 1),
        ], startPoint: .leading, endPoint: .trailing)
        .frame(height: 1.5)
        .opacity(0.85)
    }
}

/// Small rotating reminder that drops just below the notch while idle.
struct PeekNotch: View {
    @ObservedObject var model: NotchModel
    let msg: Msg
    let palestine: Bool
    @StateObject private var hv = HoverState()
    private var hover: Bool { hv.on }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchHeight)
            HStack(spacing: 10) {
                if palestine {
                    PalestineFlag().frame(width: 20, height: 13)
                } else {
                    AZSwoosh().fill(AZ.lime).frame(width: 16, height: 10)
                }
                VStack(spacing: 1) {
                    Text(msg.text).font(AZFont.ui(13, .medium)).lineLimit(2).minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                    if let s = msg.source { Text(s).font(AZFont.ui(9.5)).foregroundColor(AZ.muted).lineLimit(1) }
                }
                if StoryFeature.onMac {
                Spacer(minLength: 0)
                Button { model.onShare?(StoryPool.fromNotch(msg, palestine: palestine)); model.dismissAlert() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 10.5, weight: .semibold))
                        if hover { Text(tr("شارك")).font(AZFont.ui(10.5, .semibold)) }
                    }
                    .foregroundColor(hover ? AZ.navy : AZ.lime)
                    .padding(.horizontal, hover ? 10 : 7).padding(.vertical, 5)
                    .background(Capsule().fill(hover ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(AZ.lime.opacity(0.14))))
                }.buttonStyle(.plain).help(tr("شارك ستوري"))
                }
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hv.on = h } }
    }
}

/// "Share today's card" row in the Today tab: a small preview of the card + a clear button.
struct ShareTodayCard: View {
    let share: (StoryItem) -> Void
    var body: some View {
        let item = StoryPool.today()
        Button { share(item) } label: {
            HStack(spacing: 10) {
                // mini preview of the real story card
                StoryCard(item: item)
                    .scaleEffect(30.0 / 540.0, anchor: .topLeading)
                    .frame(width: 30, height: 53, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(trf("شارك %@ النهارده ستوري", item.title)).font(AZFont.ui(12, .semibold))
                    Text(item.text.replacingOccurrences(of: "\n", with: " ")).font(item.isQuran ? AZFont.quran(11) : AZFont.ui(10))
                        .foregroundColor(AZ.muted).lineLimit(1)
                }
                Spacer(minLength: 6)
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 10.5, weight: .bold))
                    Text(tr("شارك")).font(AZFont.ui(11, .bold))
                }
                .foregroundColor(AZ.navy)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(AZ.accentGradient))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [item.tint.opacity(0.10), Color.white.opacity(0.03)], startPoint: .leading, endPoint: .trailing)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(item.tint.opacity(0.3), lineWidth: 0.6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The evening fasting reminder as a slim strip under the notch: moon + one line.
struct FastingSlim: View {
    @ObservedObject var model: NotchModel
    let text: String
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchHeight)
            HStack(spacing: 7) {
                Image(systemName: "moon.stars.fill").font(.system(size: 11)).foregroundColor(AZ.gold)
                Text(text).font(.system(size: 12.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 16).padding(.bottom, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.dismissAlert() }
    }
}

/// Fasting line: moon + "النهارده تاني يوم من الأيام البيض · فاضل بكرة" + ● ● ○.
struct FastingChip: View {
    let status: FastingStatus
    var compact = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.stars.fill").foregroundColor(AZ.gold)
            if !compact {
                Text(status.text).lineLimit(1).minimumScaleFactor(0.8)
            }
            if status.dots > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<status.dots, id: \.self) { i in
                        Circle()
                            .fill(i < status.filled ? AnyShapeStyle(AZ.gold) : AnyShapeStyle(Color.clear))
                            .overlay(Circle().strokeBorder(AZ.gold.opacity(0.8), lineWidth: 1))
                            .frame(width: 6, height: 6)
                    }
                }
                .environment(\.layoutDirection, Lang.dir)
            }
        }
        .font(AZFont.ui(10.5, .medium))
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(AZ.gold.opacity(0.13)))
        .overlay(Capsule().strokeBorder(AZ.gold.opacity(0.4), lineWidth: 0.5))
        .help(status.text)
    }
}

struct AlertNotch: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var engine: PrayerEngine
    let alert: NotchModel.Alert

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchHeight)
            HStack(alignment: .center, spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(AZFont.ui(12, .semibold)).foregroundColor(AZ.lime)
                    Text(bodyText).font(AZFont.ui(13.5, .medium)).lineLimit(2).minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    if let sub { Text(sub).font(AZFont.ui(10.5)).foregroundColor(AZ.muted).lineLimit(1) }
                }
                Spacer(minLength: 0)
                actions
            }
            .padding(.horizontal, 22)
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder private var icon: some View {
        switch alert {
        case .fasting:
            Image(systemName: "moon.stars.fill").font(.system(size: 20)).foregroundStyle(AZ.accentGradient)
        case .nafl(let k, _), .naflCheck(let k):
            ZStack {
                Circle().fill(AZ.lime.opacity(0.13))
                Image(systemName: k.icon).font(.system(size: 15)).foregroundColor(k == .duha ? AZ.gold : AZ.violet)
            }
            .frame(width: 34, height: 34)
        case .sadaqa, .zakat:
            ZStack {
                Circle().fill(AZ.gold.opacity(0.15))
                Image(systemName: { if case .zakat = alert { return "scalemass.fill" }; return "hands.and.sparkles.fill" }())
                    .font(.system(size: 14)).foregroundColor(AZ.gold)
            }
            .frame(width: 34, height: 34)
        case .update:
            ZStack {
                Circle().fill(AZ.lime.opacity(0.13))
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 16)).foregroundColor(AZ.lime)
            }
            .frame(width: 34, height: 34)
        case .wird:
            ZStack {
                Circle().fill(AZ.lime.opacity(0.13))
                Image(systemName: "book.fill").font(.system(size: 14)).foregroundColor(AZ.lime)
            }
            .frame(width: 34, height: 34)
        case .adhkar(let k, _):
            ZStack {
                Circle().fill((k == .morning ? AZ.gold : AZ.violet).opacity(0.18))
                Image(systemName: k == .morning ? "sunrise.fill" : "sunset.fill").font(.system(size: 15))
                    .foregroundColor(k == .morning ? AZ.gold : AZ.violet)
            }
            .frame(width: 34, height: 34)
        case .ramadan:
            ZStack {
                Circle().fill(AZ.gold.opacity(0.15))
                Image(systemName: "moon.stars.fill").font(.system(size: 15)).foregroundColor(AZ.gold)
            }
            .frame(width: 34, height: 34)
        default:
            ZStack {
                Circle().fill(AZ.lime.opacity(0.13))
                AZSwoosh().fill(AZ.lime).padding(8)
            }
            .frame(width: 34, height: 34)
        }
    }

    private var title: String {
        switch alert {
        case .pre(let p, _): return trf("قرّب ميعاد %@", p.arabic(friday: engine.isFriday))
        case .peek(_, let pal): return pal ? tr("فلسطين في القلب") : tr("ذِكر")
        case .fasting: return tr("تذكير بالصيام")
        case .deferred(let p): return trf("حان وقت %@", p.arabic(friday: engine.isFriday))
        case .info(let t, _): return t
        case .ramadan(let t, _): return t
        case .adhkar(let k, _): return k.title
        case .wird: return tr("وردك اليومي من القرآن")
        case .update(let v, _): return trf("فيه تحديث جديد لـ AZ Itqan · %@", v)
        case .sadaqa: return tr("صدقة النهارده")
        case .rahim: return tr("صلة الرحم")
        case .nafl(let k, _): return k == .duha ? tr("وقت صلاة الضحى") : tr("الثلث الأخير من الليل… قيام الليل")
        case .naflCheck(let k): return k.checkTitle
        case .zakat(let t, _): return t
        case .share(let t, _): return t
        }
    }
    private var bodyText: String {
        switch alert {
        case .pre(_, let t): return trf("الأذان بعد %@ — احفظ شغلك", AR.countdown(t.timeIntervalSince(engine.now)))
        case .peek(let m, _): return m.text
        case .fasting(let titles, _): return titles.joined(separator: " · ") + tr(" — نوِيت؟")
        case .deferred: return tr("شكلك في ميتنج… هنقفل الشاشة أول ما تخلص")
        case .info(_, let b): return b
        case .ramadan(_, let b): return b
        case .adhkar(_, let m): return m.text
        case .wird(let m): return m.text
        case .update(_, let notes): return notes
        case .sadaqa(let m): return m.text
        case .rahim(_, let m, _): return m.text
        case .zakat(_, let b): return b
        case .share(_, let b): return b
        case .nafl(_, let m): return m.text
        case .naflCheck(let k): return k == .duha ? tr("لو صلّيتها، سجّلها عشان تبان في تقريرك") : tr("لو قمت، سجّلها عشان تبان في تقريرك")
        }
    }
    private var sub: String? {
        switch alert {
        case .peek(let m, _): return m.source
        case .fasting(_, let d): return d
        case .pre(let p, let t): return "\(p.arabic(friday: engine.isFriday)) \(AR.time(t, tz: engine.tz, ampm: true))"
        case .adhkar(_, let m): return m.source
        case .sadaqa(let m): return m.source
        case .nafl(_, let m): return m.source
        case .wird:
            let r = QuranWird.shared.range(pages: engine.settings.wirdPages)
            return trf("%@ صفحات · من صفحة %@ لـ %@", AR.num(engine.settings.wirdPages), AR.num(r.from), AR.num(r.to))
        default: return nil
        }
    }

    @ViewBuilder private var actions: some View {
        if case .pre(let p, _) = alert, Buddy.enabled {
            Button { Buddy.send(p, friday: engine.isFriday) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill").font(.system(size: 10, weight: .bold))
                    Text(Buddy.buttonTitle).font(AZFont.ui(11, .semibold)).lineLimit(1)
                }
                .foregroundColor(AZ.navy)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(AZ.accentGradient))
            }.buttonStyle(.plain)
        } else if case .nafl(let k, _) = alert {
            VStack(spacing: 5) {
                Button { model.onNaflCommit?(k) } label: {
                    Text(k.commitText).font(AZFont.ui(11, .bold)).foregroundColor(AZ.navy)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(AZ.accentGradient))
                }.buttonStyle(.plain)
                Button {
                    model.show(.info(tr("ربنا يعينك"), tr("بكرة إن شاء الله… ولو ركعتين")), for: 5)
                } label: {
                    Text(tr("مش النهارده")).font(AZFont.ui(10)).foregroundColor(AZ.muted).underline()
                }.buttonStyle(.plain)
            }
        } else if case .naflCheck(let k) = alert {
            VStack(spacing: 5) {
                Button {
                    Nafl.mark(k)
                    model.show(.info(tr("ما شاء الله… تقبّل الله"), tr("اتسجلت في تقريرك")), for: 5)
                } label: {
                    Text(tr("الحمد لله ✓")).font(AZFont.ui(11, .bold)).foregroundColor(AZ.navy)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(AZ.accentGradient))
                }.buttonStyle(.plain)
                Button { model.dismissAlert() } label: {
                    Text(tr("لسه")).font(AZFont.ui(10)).foregroundColor(AZ.muted).underline()
                }.buttonStyle(.plain)
            }
        } else if case .sadaqa = alert {
            Button { SadaqaLog.shared.markGiven(); model.dismissAlert() } label: {
                Text(tr("طلّعت ✓")).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(AZ.accentGradient))
            }.buttonStyle(.plain)
        } else if case .zakat = alert {
            Button { model.alert = nil; withAnimation(NotchAnim.open) { model.tab = 2; model.expanded = true } } label: {
                Text(tr("احسبها")).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(LinearGradient(colors: [AZ.gold, AZ.lime], startPoint: .leading, endPoint: .trailing)))
            }.buttonStyle(.plain)
        } else if case .update = alert {
            Button { UpdateChecker.shared.download(); model.dismissAlert() } label: {
                Text(tr("حمّل التحديث")).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(AZ.accentGradient))
            }.buttonStyle(.plain)
        } else if case .wird = alert {
            Button { QuranWird.shared.openMushaf(); model.dismissAlert() } label: {
                Text(tr("افتح المصحف")).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(AZ.accentGradient))
            }.buttonStyle(.plain)
        } else if case .adhkar(let k, _) = alert {
            Button { model.openReader(k) } label: {
                Text(tr("اقرأها")).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(AZ.accentGradient))
            }.buttonStyle(.plain)
        } else if case .share = alert {
            Button { model.onShare?(nil); model.dismissAlert() } label: {
                Label(tr("شارك"), systemImage: "square.and.arrow.up").font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(AZ.accentGradient))
            }.buttonStyle(.plain)
        } else if case .ramadan = alert {
            Button { model.onOpenRamadan?(); model.dismissAlert() } label: {
                Text(RamadanPlan.shared.goals.isEmpty ? tr("سجّل خطتك") : tr("افتح خطتي")).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(LinearGradient(colors: [AZ.gold, AZ.lime], startPoint: .leading, endPoint: .trailing)))
            }.buttonStyle(.plain)
        } else if case .deferred(let p) = alert {
            Button { model.onLockNow?(p); model.dismissAlert() } label: {
                Text(tr("صلّي دلوقتي")).font(AZFont.ui(11, .semibold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AZ.accentGradient))
            }.buttonStyle(.plain)
        } else {
            Button { model.dismissAlert() } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.muted)
                    .frame(width: 22, height: 22).background(Circle().fill(Color.white.opacity(0.08)))
            }.buttonStyle(.plain)
        }
    }
}

struct ExpandedNotch: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var engine: PrayerEngine

    var body: some View {
        let next = engine.next
        let tz = engine.tz
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    AZSwoosh().fill(AZ.lime).frame(width: 16, height: 10)
                    Text(engine.settings.location.name).font(AZFont.ui(11.5, .semibold)).lineLimit(1)
                }
                Spacer(minLength: model.notchWidth + 10)
                Text("\(AR.weekday(engine.now, tz: tz)) · \(Hijri.string(engine.now, adjust: engine.settings.hijriAdjust))")
                    .font(AZFont.ui(10.5)).foregroundColor(AZ.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(height: model.notchHeight)
            .padding(.horizontal, 26)

            tabBar

            if model.tab == 1 {
                ReportTab(engine: engine).padding(.horizontal, 18)
            } else if model.tab == 2 {
                GivingTab(adjust: engine.settings.hijriAdjust).padding(.horizontal, 18)
            } else {
            HStack(spacing: 6) {
                ForEach(Prayer.allCases, id: \.self) { p in
                    let isNext = p == next.prayer && next.time == engine.today[p]
                    VStack(spacing: 3) {
                        Text(p.arabic(friday: engine.isFriday)).font(AZFont.ui(10.5, .medium))
                            .foregroundColor(isNext ? AZ.lime : AZ.muted)
                        Text(engine.today[p].map { AR.time($0, tz: tz) } ?? "—")
                            .font(AZFont.ui(15, .semibold).monospacedDigit())
                            .foregroundColor(p == .sunrise ? AZ.muted : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(isNext ? AnyShapeStyle(LinearGradient(colors: [AZ.royal.opacity(0.55), AZ.indigo.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(AZ.cardGradient))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(isNext ? AZ.lime.opacity(0.8) : AZ.line, lineWidth: isNext ? 1 : 0.5))
                }
            }
            .padding(.horizontal, 18)

            VStack(spacing: 4) {
                HStack {
                    Text(trf("%@ بعد %@", next.prayer.arabic(friday: engine.isFriday), AR.countdown(next.time.timeIntervalSince(engine.now))))
                        .font(AZFont.ui(11.5, .semibold))
                    Spacer()
                    if model.owedPrayer != nil, let f = Fasting.status(on: engine.now, adjust: engine.settings.hijriAdjust) {
                        FastingChip(status: f, compact: true)
                    }
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(LinearGradient(colors: [AZ.violet, AZ.lime], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, g.size.width * engine.progress))
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 22)

            HStack(spacing: 8) {
                ramadanCard
                palestineCard
            }
            .padding(.horizontal, 18)

            HStack(spacing: 8) {
                WirdCard(settings: engine.settings)
                adhkarCard
            }
            .padding(.horizontal, 18)

            if StoryFeature.onMac {
                ShareTodayCard { model.onShare?($0) }
                    .padding(.horizontal, 18)
            }

            HStack(spacing: 8) {
                if let owed = model.owedPrayer {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.exclamationmark").foregroundColor(AZ.gold)
                        Text(trf("لسه ما صلّيتش %@", owed.arabic(friday: engine.isFriday))).lineLimit(1)
                        Button { model.onConfirmOwed?() } label: {
                            Text(tr("صلّيت")).font(AZFont.ui(10.5, .bold)).foregroundColor(AZ.navy)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(Capsule().fill(AZ.accentGradient))
                        }.buttonStyle(.plain)
                    }
                    .font(AZFont.ui(10.5, .medium))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(AZ.gold.opacity(0.13)))
                    .overlay(Capsule().strokeBorder(AZ.gold.opacity(0.4), lineWidth: 0.5))
                } else if let f = Fasting.status(on: engine.now, adjust: engine.settings.hijriAdjust) {
                    FastingChip(status: f)
                } else if let t = Fasting.tomorrowPhrase(after: engine.now, adjust: engine.settings.hijriAdjust) {
                    FastingChip(status: FastingStatus(text: t + tr(" إن شاء الله")))
                }
                Spacer(minLength: 4)
                if false, let k = MorningEvening.current(engine: engine) {
                    Button { model.onOpenAdhkar?(k) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: k == .morning ? "sunrise.fill" : "sunset.fill")
                                .foregroundColor(k == .morning ? AZ.gold : AZ.violet)
                            Text(k.title)
                        }
                        .font(AZFont.ui(10.5, .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                        .overlay(Capsule().strokeBorder(AZ.line, lineWidth: 0.5))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(Array([tr("اليوم"), tr("التقرير"), tr("العطاء")].enumerated()), id: \.offset) { i, title in
                    Button { withAnimation(.easeInOut(duration: 0.18)) { model.tab = i } } label: {
                        Text(title).font(AZFont.ui(11, model.tab == i ? .bold : .medium))
                            .foregroundColor(model.tab == i ? AZ.navy : AZ.muted)
                            .frame(width: 70).padding(.vertical, 4)
                            .background(Capsule().fill(model.tab == i ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(Color.clear)))
                    }.buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            Spacer(minLength: 0)
        }
        .overlay(alignment: .leading) {
            if StoryFeature.onMac { Button { model.onShare?(nil) } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 11.5)).foregroundColor(AZ.muted)
                    .frame(width: 24, height: 24).background(Circle().fill(Color.white.opacity(0.06)))
            }.buttonStyle(.plain).help(tr("شارك ستوري")) }
        }
        .overlay(alignment: .trailing) {
            Button { model.onOpenSettings?() } label: {
                Image(systemName: "gearshape").font(.system(size: 12)).foregroundColor(AZ.muted)
                    .frame(width: 24, height: 24).background(Circle().fill(Color.white.opacity(0.06)))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
    }

    /// Morning/evening adhkar entry: opens the reader inside the notch.
    private var adhkarCard: some View {
        let k = MorningEvening.current(engine: engine)
            ?? (Calendar.current.component(.hour, from: engine.now) < 12 ? .morning : .evening)
        let done = MorningEvening.isDone(k)
        let s = AdhkarSession.shared
        let progress = s.kind == k ? s.completed : 0
        return Button { model.openReader(k) } label: {
            HStack(spacing: 9) {
                Image(systemName: k == .morning ? "sunrise.fill" : "sunset.fill")
                    .font(.system(size: 15)).foregroundColor(k == .morning ? AZ.gold : AZ.violet)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill((k == .morning ? AZ.gold : AZ.violet).opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(k.title).font(AZFont.ui(12, .semibold))
                    Text(done ? tr("خلّصتها ✓ ما شاء الله") : trf("%@ من %@ · اقرأها هنا", AR.num(progress), AR.num(MorningEvening.list(k).count)))
                        .font(AZFont.ui(9.5)).foregroundColor(done ? AZ.lime : AZ.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.muted)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 14).fill(AZ.cardGradient))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Ramadan countdown card + the next goal from "my Ramadan plan".
    private var ramadanCard: some View {
        let plan = RamadanPlan.shared
        let next = plan.pending.first?.text
        let inRamadan = engine.ramadanDay != nil
        return Button { model.onOpenRamadan?() } label: {
            HStack(spacing: 10) {
                VStack(spacing: 0) {
                    Text(AR.num(engine.ramadanDay ?? engine.ramadanDays)).font(AZFont.ui(22, .bold).monospacedDigit())
                        .foregroundColor(AZ.gold)
                    Text(inRamadan ? tr("من رمضان") : tr("يوم")).font(AZFont.ui(9.5, .medium)).foregroundColor(AZ.muted)
                }
                .frame(width: 46, height: 46)
                .background(Circle().fill(AZ.gold.opacity(0.12)))
                .overlay(Circle().strokeBorder(AZ.gold.opacity(0.35), lineWidth: 0.8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(inRamadan ? tr("رمضان كريم") : trf("رمضان %@", AR.num(plan.year))).font(AZFont.ui(13, .semibold))
                    Text(next.map { trf("خطتك: %@", $0) } ?? tr("اكتب خطتك من دلوقتي"))
                        .font(AZFont.ui(9.5)).foregroundColor(AZ.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(plan.goals.isEmpty ? tr("سجّل خطتك") : tr("خطتي"))
                    .font(AZFont.ui(10.5, .bold)).foregroundColor(AZ.navy).lineLimit(1).fixedSize()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(LinearGradient(colors: [AZ.gold, AZ.lime], startPoint: .leading, endPoint: .trailing)))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(
                colors: [AZ.gold.opacity(0.14), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tr("خطتي لرمضان"))
    }

    /// Always-visible Ramadan countdown + entry to "my Ramadan plan".
    private var ramadanChip: some View {
        let goals = RamadanPlan.shared.goals.count
        let head = engine.ramadanDay.map { trf("رمضان · اليوم %@", AR.num($0)) } ?? trf("رمضان بعد %@ يوم", AR.num(engine.ramadanDays))
        return Button { model.onOpenRamadan?() } label: {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill").foregroundColor(AZ.gold)
                Text(head).foregroundColor(.white)
                Text(goals > 0 ? trf("خطتي (%@)", AR.num(goals)) : tr("اكتب خطتك"))
                    .font(AZFont.ui(10, .bold)).foregroundColor(AZ.navy)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(LinearGradient(colors: [AZ.gold, AZ.lime], startPoint: .leading, endPoint: .trailing)))
            }
            .font(AZFont.ui(10.5, .semibold))
            .lineLimit(1)
            .padding(.leading, 9).padding(.trailing, 4).padding(.vertical, 3)
            .background(Capsule().fill(AZ.gold.opacity(0.12)))
            .overlay(Capsule().strokeBorder(AZ.gold.opacity(0.4), lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tr("خطتي لرمضان"))
    }

    private var tasbihCard: some View {
        let phrase = Adhkar.tasbih[(model.tasbih / 33) % 3]
        let count = model.tasbih % 33
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { model.tasbih += 1 }
            if (model.tasbih % 33) == 0 { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                    Circle().trim(from: 0, to: CGFloat(count) / 33)
                        .stroke(AZ.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(AR.num(count)).font(AZFont.ui(13, .bold).monospacedDigit())
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(phrase).font(AZFont.ui(13, .semibold))
                    Text(trf("اضغط للتسبيح · %@ الإجمالي", AR.num(model.tasbih))).font(AZFont.ui(9.5)).foregroundColor(AZ.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(RoundedRectangle(cornerRadius: 14).fill(AZ.cardGradient))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var palestineCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { model.palestineMsg = MessagePicker.palestineRotator.pick(Palestine.items) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    PalestineFlag().frame(width: 18, height: 12)
                    Text(tr("فلسطين")).font(AZFont.ui(11, .semibold))
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9)).foregroundColor(AZ.muted)
                }
                Text(model.palestineMsg.text).font(AZFont.ui(11)).lineLimit(2).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                if let s = model.palestineMsg.source { Text(s).font(AZFont.ui(9)).foregroundColor(AZ.muted) }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(LinearGradient(
                    colors: [Color(hex: 0x149954).opacity(0.22), Color.white.opacity(0.03), Color(hex: 0xE4312B).opacity(0.16)],
                    startPoint: .topTrailing, endPoint: .bottomLeading))
            )
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Quran wird card

struct WirdCard: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var wird = QuranWird.shared

    var body: some View {
        let r = wird.range(pages: settings.wirdPages)
        HStack(spacing: 9) {
            Image(systemName: "book.fill").font(.system(size: 14)).foregroundColor(AZ.lime)
                .frame(width: 30, height: 30).background(Circle().fill(AZ.lime.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Text(wird.doneToday ? tr("قرأت وردك ✓") : trf("وردك: %@ صفحات", AR.num(settings.wirdPages))).font(AZFont.ui(12, .semibold))
                Text(wird.doneToday
                     ? (wird.streak > 1 ? trf("%@ أيام ورا بعض · ما شاء الله", AR.num(wird.streak)) : tr("ما شاء الله… تقبّل الله"))
                     : trf("من صفحة %@ لـ %@", AR.num(r.from), AR.num(r.to)))
                    .font(AZFont.ui(9.5)).foregroundColor(wird.doneToday ? AZ.lime : AZ.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            if !wird.doneToday {
                Button { wird.openMushaf() } label: {
                    Image(systemName: "arrow.up.left").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.lime)
                        .frame(width: 24, height: 24).background(Circle().fill(AZ.lime.opacity(0.12)))
                }.buttonStyle(.plain).help(trf("افتح المصحف على صفحة %@", AR.num(r.from)))
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { wird.markRead(pages: settings.wirdPages) } } label: {
                    Text(tr("قرأت")).font(AZFont.ui(10.5, .bold)).foregroundColor(AZ.navy)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(AZ.accentGradient))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(
            colors: [AZ.lime.opacity(0.10), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.line, lineWidth: 0.5))
    }
}

// MARK: - Adhkar reader inside the notch

struct AdhkarNotchReader: View {
    @ObservedObject var model: NotchModel
    @ObservedObject var session: AdhkarSession
    let kind: MorningEvening.Kind

    var body: some View {
        let items = session.items
        let d = session.current
        let c = session.counts[d.id, default: 0]
        let done = c >= d.count
        let allDone = session.completed == items.count
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: kind == .morning ? "sunrise.fill" : "sunset.fill")
                        .foregroundColor(kind == .morning ? AZ.gold : AZ.violet)
                    Text(kind.title).font(AZFont.ui(12, .semibold))
                }
                Spacer(minLength: model.notchWidth + 10)
                Button { withAnimation(NotchAnim.close) { model.reader = nil } } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(AZ.muted)
                        .frame(width: 22, height: 22).background(Circle().fill(Color.white.opacity(0.08)))
                }.buttonStyle(.plain)
            }
            .frame(height: model.notchHeight)
            .padding(.horizontal, 26)

            VStack(spacing: 4) {
                HStack {
                    Text(trf("%@ من %@", AR.num(session.completed), AR.num(items.count)))
                    Spacer()
                    if allDone { Text(tr("تقبّل الله… ما شاء الله")).foregroundColor(AZ.lime) }
                }
                .font(AZFont.ui(10.5, .medium)).foregroundColor(AZ.muted)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(AZ.accentGradient)
                            .frame(width: max(6, g.size.width * CGFloat(session.completed) / CGFloat(max(1, items.count))))
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)

            // Tap anywhere on the card to count
            Button { session.tapCurrent() } label: {
                VStack(spacing: 10) {
                    if let note = d.note { Text(note).font(AZFont.ui(10.5, .bold)).foregroundColor(AZ.gold) }
                    Text(d.text)
                        .font(AZFont.naskh(19))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(7)
                        .foregroundColor(done ? AZ.muted : .white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack(spacing: 6) {
                        if done { Image(systemName: "checkmark") }
                        Text(d.count == 1 ? (done ? tr("تم") : tr("مرة واحدة")) : "\(AR.num(c)) / \(AR.num(d.count))")
                    }
                    .font(AZFont.ui(12, .bold))
                    .foregroundColor(done ? AZ.navy : AZ.lime)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(done ? AnyShapeStyle(AZ.accentGradient) : AnyShapeStyle(AZ.lime.opacity(0.12))))
                }
                .id(d.id)
                .transition(.opacity)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(AZ.cardGradient))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AZ.line, lineWidth: 0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            HStack {
                Button { session.step(-1) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right").environment(\.layoutDirection, .leftToRight)
                        Text(tr("السابق"))
                    }
                }
                Spacer()
                Text(tr("اضغط على الذِكر كل ما تقوله")).foregroundColor(AZ.muted)
                Spacer()
                Button { session.step(1) } label: {
                    HStack(spacing: 4) {
                        Text(tr("التالي"))
                        Image(systemName: "chevron.left").environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
            .buttonStyle(.plain)
            .font(AZFont.ui(10.5, .medium))
            .padding(.horizontal, 26)
            .padding(.bottom, 12)
        }
    }
}
