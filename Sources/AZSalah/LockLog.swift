import Foundation

/// Tiny diagnostic log of why the prayer screen appeared (~/Library/Logs/AZ Itqan.log, capped at ~200 KB).
enum LockLog {
    private static let url: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("AZ Itqan.log")
    }()

    static func write(_ line: String) {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let text = "\(f.string(from: Date()))  \(line)\n"
        if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, size > 200_000 {
            try? FileManager.default.removeItem(at: url)
        }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(text.data(using: .utf8)!); try? h.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
