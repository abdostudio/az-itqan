import SwiftUI
import AVFoundation

/// Short explainer video comparing idle-notch options (menu bar coverage). `--notch-demo <dir>`
struct NotchDemoFrame: View {
    let t: Double
    static let notchW: CGFloat = 185, barH: CGFloat = 32
    private let cx: CGFloat = 480

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(hex: 0x0B1F5C), Color(hex: 0x0A3BA8), Color(hex: 0x061230)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(hex: 0x5B8CFF).opacity(0.35), .clear], center: UnitPoint(x: 0.7, y: 0.8), startRadius: 0, endRadius: 500)
            menuBar
            island
            cursor
            caption
            // red marks on both sides where the wide strip hides menu items / icons
            if t < 5.2 {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    RoundedRectangle(cornerRadius: 7).strokeBorder(Color(hex: 0xFF8A80), lineWidth: 2)
                        .frame(width: 66, height: 30)
                        .position(x: cx + CGFloat(side) * 126, y: 16)
                        .opacity(0.55 + 0.45 * sin(t * 6))
                }
            }
        }
        .frame(width: 960, height: 540)
        .clipped()
        .foregroundColor(.white)
    }

    // MARK: menu bar with icons right next to the notch
    private var menuBar: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.black.opacity(0.28)).frame(width: 960, height: Self.barH)
            HStack(spacing: 16) {
                Image(systemName: "applelogo").font(.system(size: 13, weight: .semibold))
                Text("Finder").bold(); Text("File"); Text("Edit"); Text("View"); Text("Go"); Text("Window"); Text("Help")
            }
            .font(.system(size: 12.5)).padding(.leading, 18).frame(height: Self.barH)
            ForEach(Array(icons.enumerated()), id: \.offset) { i, ic in
                Image(systemName: ic).font(.system(size: 13, weight: .medium))
                    .frame(width: 22, height: Self.barH)
                    .position(x: cx + 104 + CGFloat(i) * 30, y: Self.barH / 2)
            }
            Text("Wed 2:17 PM").font(.system(size: 12.5)).position(x: 900, y: Self.barH / 2)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: 960, height: 540, alignment: .topLeading)
    }
    private let icons = ["paintbrush.pointed.fill", "music.note", "cloud.fill", "wifi", "battery.75percent", "magnifyingglass", "switch.2"]

    // MARK: timeline
    private enum Mode { case wide, notchOnly, hover, breath, lastMinutes, wing }
    private var mode: Mode {
        switch t {
        case ..<5.2: return .wide
        case 5.2..<8.4: return .notchOnly
        case 8.4..<10.6: return .hover
        case 10.6..<12.0: return .notchOnly
        case 12.0..<15.0: return .breath
        case 15.0..<16.0: return .notchOnly
        case 16.0..<19.5: return .lastMinutes
        case 19.5..<20.3: return .notchOnly
        default: return .wing
        }
    }
    private var changes: [Double] { [0, 5.2, 8.4, 10.6, 12.0, 15.0, 16.0, 19.5, 20.3] }

    private func size(_ m: Mode) -> CGSize {
        switch m {
        case .wide, .hover, .lastMinutes: return CGSize(width: Self.notchW + 132, height: Self.barH)
        case .notchOnly: return CGSize(width: Self.notchW, height: Self.barH)
        case .breath: return CGSize(width: 400, height: Self.barH + 26)
        case .wing: return CGSize(width: Self.notchW + 44, height: Self.barH)
        }
    }
    private func spring(_ x: Double) -> Double { x >= 1 ? 1 : 1 - exp(-5.2 * x) * cos(10.5 * x) }

    private var island: some View {
        let i = changes.lastIndex { $0 <= t } ?? 0
        let prevMode: Mode = i > 0 ? modeAt(changes[i - 1]) : mode
        let e = spring(M.p(t, changes[i], 0.75))
        let a = size(prevMode), b = size(mode)
        let w = M.lerp(a.width, b.width, e), h = max(Self.barH, M.lerp(a.height, b.height, e))
        let show = M.out(M.p(t, changes[i] + 0.15, 0.35))
        return ZStack(alignment: .top) {
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55),
                                   .init(color: AZ.navy, location: 0.8), .init(color: AZ.indigo.opacity(0.85), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            content(mode).opacity(show).frame(width: b.width, height: b.height, alignment: .top)
        }
        .frame(width: w, height: h, alignment: .top)
        .clipShape(NotchShape(radius: h > Self.barH + 2 ? 14 : 10))
        .overlay(alignment: .top) {
            // the camera housing itself, always there
            UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9).fill(Color.black)
                .frame(width: Self.notchW - 20, height: Self.barH)
        }
        .position(x: cx, y: h / 2)
    }
    private func modeAt(_ time: Double) -> Mode { NotchDemoFrame(t: time).mode }

    @ViewBuilder private func content(_ m: Mode) -> some View {
        switch m {
        case .wide, .hover, .lastMinutes:
            HStack {
                HStack(spacing: 5) {
                    Circle().trim(from: 0, to: 0.7).stroke(AZ.lime, lineWidth: 2.2).rotationEffect(.degrees(-90)).frame(width: 12, height: 12)
                    Text(m == .lastMinutes ? "١٤ د" : "٢:١٧ س").font(AZFont.ui(12.5, .semibold)).foregroundColor(AZ.muted)
                }
                Spacer()
                HStack(spacing: 5) {
                    Text("العصر").font(AZFont.ui(12.5, .bold))
                    Capsule().fill(AZ.violet).frame(width: 12, height: 3).rotationEffect(.degrees(-25))
                }
            }
            .padding(.horizontal, 12).frame(height: Self.barH)
            .environment(\.layoutDirection, .leftToRight)
        case .breath:
            VStack(spacing: 0) {
                Color.clear.frame(height: Self.barH)
                Text("سبحان الله وبحمده عدد خلقه ورضا نفسه").font(AZFont.ui(13, .semibold)).frame(height: 24)
            }
        case .wing:
            HStack {
                Spacer()
                Circle().trim(from: 0, to: 0.7).stroke(AZ.lime, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 13, height: 13).padding(.trailing, 6)
            }
            .frame(height: Self.barH)
            .environment(\.layoutDirection, .leftToRight)
        case .notchOnly: Color.clear
        }
    }

    // MARK: cursor (hover demo)
    private var cursor: some View {
        let inP = M.inOut(M.p(t, 7.4, 1.0)), outP = M.inOut(M.p(t, 10.3, 0.8))
        let x = M.lerp(700, cx + 20, inP), y = M.lerp(260, 14, inP) + M.lerp(0, 230, outP)
        return Image(systemName: "cursorarrow").font(.system(size: 22)).shadow(radius: 2)
            .position(x: x + 8, y: y + 10)
            .opacity(t > 7.2 && t < 11.3 ? 1 : 0)
    }

    // MARK: captions
    private var caption: some View {
        let items: [(Double, Double, String, String)] = [
            (0, 5.2, "دلوقتي", "الشريط أعرض من الكاميرا… وبيغطي أيقونات البار"),
            (5.2, 8.4, "الحل ١", "في حجم الكاميرا بالظبط… كل الأيقونات باينة"),
            (8.4, 11.3, "الحل ١", "تقف عليها بالماوس… تظهر الصلاة والعداد"),
            (11.3, 15.2, "الحل ١", "وكل شوية تتنفّس بذِكر… وترجع"),
            (15.2, 20.3, "الحل ١", "وآخر ١٥ دقيقة قبل الأذان… العداد يظهر لوحده"),
            (20.3, 30, "الحل ٢", "جناح صغير بس للعداد… بيغطي أقل حاجة"),
        ]
        return ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { _, c in
                if t >= c.0 && t < c.1 {
                    let a = M.out(M.p(t, c.0, 0.4)) * (1 - M.p(t, c.1 - 0.25, 0.25))
                    VStack(spacing: 10) {
                        Text(c.2).font(AZFont.ui(18, .bold)).foregroundColor(AZ.navy)
                            .padding(.horizontal, 16).padding(.vertical, 5).background(Capsule().fill(c.2 == "دلوقتي" ? Color(hex: 0xFF8A80) : AZ.lime))
                        Text(c.3).font(AZFont.ui(30, .bold)).multilineTextAlignment(.center)
                    }
                    .opacity(a).offset(y: (1 - a) * 14)
                }
            }
        }
        .frame(width: 960, height: 540)
        .offset(y: 60)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

enum NotchDemo {
    @MainActor
    static func render(to dir: URL) {
        RenderMode.offscreen = true
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent("notch-options.mp4")
        try? FileManager.default.removeItem(at: out)
        let W = 1920, H = 1080, fps: Int32 = 30, duration = 25.0
        guard let writer = try? AVAssetWriter(outputURL: out, fileType: .mp4) else { return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000],
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
        ])
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
        for i in 0..<Int(duration * Double(fps)) {
            let t = Double(i) / Double(fps)
            autoreleasepool {
                let r = ImageRenderer(content: NotchDemoFrame(t: t)); r.scale = 2
                guard let img = r.cgImage, let pool = adaptor.pixelBufferPool else { return }
                if [2.0, 6.0, 9.6, 13.5, 17.5, 22.0].contains(where: { abs($0 - t) < 0.01 }) {
                    try? NSBitmapImageRep(cgImage: img).representation(using: .jpeg, properties: [:])?
                        .write(to: dir.appendingPathComponent(String(format: "demo%04.1f.jpg", t)))
                }
                var pb: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
                guard let buf = pb else { return }
                CVPixelBufferLockBaseAddress(buf, [])
                let cg = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
                cg?.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
                CVPixelBufferUnlockBaseAddress(buf, [])
                while !input.isReadyForMoreMediaData { usleep(2000) }
                adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
            }
        }
        input.markAsFinished()
        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        while sem.wait(timeout: .now() + 0.05) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        print("demo written: \(out.path)")
    }
}
