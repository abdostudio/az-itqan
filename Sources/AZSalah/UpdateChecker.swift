import Foundation
import AppKit

/// Checks GitHub Releases once a day for a newer version (`version.json` attached to the latest release).
/// Feed URL comes from Info.plist `AZUpdateFeed` (set by release.sh); empty = checking is off.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    struct Release: Decodable, Equatable {
        let version: String
        let notes: String
        let url: String
    }

    @Published private(set) var latest: Release?
    @Published private(set) var status = ""
    var onAvailable: ((Release) -> Void)?

    let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    private var feed: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "AZUpdateFeed") as? String, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    private var timer: Timer?

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in self?.check(manual: false) }
        let t = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in self?.check(manual: false) }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Automatic checks run at most once a day; the button in settings always checks.
    func check(manual: Bool) {
        guard let feed else { status = tr("التحديثات لسه مش متوصّلة"); return }
        let last = UserDefaults.standard.double(forKey: "update.lastCheck")
        if !manual, Date().timeIntervalSince1970 - last < 20 * 3600 { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "update.lastCheck")
        status = tr("بنشيّك…")
        var req = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.setValue("AZ-Itqan/\(current)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, let r = try? JSONDecoder().decode(Release.self, from: data) else {
                    self.status = tr("مقدرناش نوصل لسيرفر التحديثات"); return
                }
                if Self.isNewer(r.version, than: self.current) {
                    self.latest = r
                    self.status = trf("فيه نسخة جديدة: %@", r.version)
                    // Don't repeat the notch alert for the same version more than once a day.
                    let key = "update.alerted.\(r.version)"
                    let lastAlert = UserDefaults.standard.double(forKey: key)
                    if manual || Date().timeIntervalSince1970 - lastAlert > 20 * 3600 {
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
                        self.onAvailable?(r)
                    }
                } else {
                    self.latest = nil
                    self.status = tr("إنت على آخر نسخة ✓")
                }
            }
        }.resume()
    }

    func download() {
        if let s = latest?.url, let u = URL(string: s) { NSWorkspace.shared.open(u) }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").compactMap { Int($0) }, pb = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
