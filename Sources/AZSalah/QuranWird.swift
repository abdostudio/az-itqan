import Foundation
import AppKit

/// Daily Quran portion ("الورد اليومي"): N pages a day through the 604-page mushaf, tracked on this Mac.
final class QuranWird: ObservableObject {
    static let shared = QuranWird()
    static let totalPages = 604
    private let d = UserDefaults.standard

    @Published private(set) var page: Int          // first page of today's portion
    @Published private(set) var streak: Int
    @Published private(set) var doneToday: Bool
    @Published private(set) var khatmas: Int

    private init() {
        page = max(1, d.integer(forKey: "wird.page"))
        streak = d.integer(forKey: "wird.streak")
        khatmas = d.integer(forKey: "wird.khatmas")
        doneToday = false
        refresh()
    }

    private static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// Re-evaluates "done today" and breaks the streak if a day was missed.
    func refresh() {
        let last = d.string(forKey: "wird.lastDay")
        let today = Self.dayString(Date())
        let yesterday = Self.dayString(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        doneToday = last == today
        if let last, last != today, last != yesterday, streak != 0 {
            streak = 0; d.set(0, forKey: "wird.streak")
        }
    }

    func range(pages: Int) -> (from: Int, to: Int) {
        (page, min(Self.totalPages, page + max(1, pages) - 1))
    }

    var khatmaProgress: Double { Double(page - 1) / Double(Self.totalPages) }

    /// "قرأت وردي": advance the bookmark, keep the streak.
    func markRead(pages: Int) {
        guard !doneToday else { return }
        var next = range(pages: pages).to + 1
        if next > Self.totalPages {
            next = 1
            khatmas += 1; d.set(khatmas, forKey: "wird.khatmas")
        }
        page = next; d.set(page, forKey: "wird.page")
        streak += 1; d.set(streak, forKey: "wird.streak")
        d.set(Self.dayString(Date()), forKey: "wird.lastDay")
        doneToday = true
    }

    func setPage(_ p: Int) {
        page = min(Self.totalPages, max(1, p)); d.set(page, forKey: "wird.page")
    }

    /// Opens today's first page on quran.com (one click, no searching).
    func openMushaf() {
        if let url = URL(string: "https://quran.com/page/\(page)") { NSWorkspace.shared.open(url) }
    }

    static let motivation: [Msg] = [
        Msg(tr("خيركم من تعلّم القرآن وعلّمه"), tr("رواه البخاري")),
        Msg(tr("اقرؤوا القرآن فإنه يأتي يوم القيامة شفيعًا لأصحابه"), tr("رواه مسلم")),
        Msg(tr("من قرأ حرفًا من كتاب الله فله به حسنة، والحسنة بعشر أمثالها"), tr("رواه الترمذي")),
        Msg(tr("إنّ هذا القرآن يهدي للتي هي أقوم"), tr("الإسراء ٩")),
        Msg(tr("كتابٌ أنزلناه إليك مباركٌ ليدّبّروا آياته"), tr("ص ٢٩")),
        Msg(tr("وردك عشر دقايق… أقل من سكرول واحد على السوشيال"), tr("اقفل الشاشة دي وافتح المصحف")),
        Msg(tr("قبل ما تفتح فيجما… افتح المصحف"), tr("الورد اليومي بيظبط بوصلة يومك")),
        Msg(tr("صفحات قليلة كل يوم… وختمة كاملة بإذن الله"), tr("الاستمرار أهم من الكتير")),
    ]
    static let rotator = Rotator(key: "recent.wird", memory: 4)
}
