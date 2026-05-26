import AppKit
import QuickLookUI
import SwiftUI
import PeekyCore

/// Quick Look이 미리보기를 요청할 때 macOS가 인스턴스화하는 principal class.
/// Info.plist의 NSExtensionPrincipalClass = "PeekyQuickLook.PreviewViewController"에 매칭된다.
@objc(PreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        view.wantsLayer = true
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let inspection = try await Self.inspect(url: url)
        await MainActor.run {
            let host = NSHostingView(rootView: InspectionView(inspection: inspection))
            host.frame = view.bounds
            host.autoresizingMask = [.width, .height]
            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(host)
        }
    }

    /// Phase 0 스켈레톤 — 파일 확장자 분기만. Phase 2부터 실제 검사 로직 연결.
    private static func inspect(url: URL) async throws -> Inspection {
        switch url.pathExtension.lowercased() {
        case "app":
            let bundle = try BundleInspector.inspectAppBundle(at: url)
            return Inspection(source: .app(url), bundle: bundle)
        case "appex":
            let bundle = try BundleInspector.inspectAppBundle(at: url)
            return Inspection(source: .appex(url), bundle: bundle)
        case "ipa":
            return Inspection(source: .ipa(url), warnings: ["IPA 지원은 Phase 6에서 구현 예정"])
        case "xcarchive":
            return Inspection(source: .xcarchive(url), warnings: ["xcarchive 지원은 Phase 7에서 구현 예정"])
        case "mobileprovision", "provisionprofile":
            let (profile, entitlements) = try ProfileDecoder.decode(at: url)
            return Inspection(source: .profile(url), profile: profile, entitlements: entitlements)
        default:
            throw PeekyError.unsupportedSource(url: url)
        }
    }
}
