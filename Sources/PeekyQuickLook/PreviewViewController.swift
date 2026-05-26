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

    /// 파일 확장자별 검사 디스패치.
    private static func inspect(url: URL) async throws -> Inspection {
        switch url.pathExtension.lowercased() {
        case "app", "appex":
            return try BundleInspector.inspect(bundleAt: url)
        case "ipa":
            return try IPAInspector.inspect(ipaAt: url)
        case "xcarchive":
            return try XCArchiveInspector.inspect(archiveAt: url)
        case "mobileprovision", "provisionprofile":
            let (profile, entitlements) = try ProfileDecoder.decode(at: url)
            return Inspection(source: .profile(url), profile: profile, entitlements: entitlements)
        default:
            throw PeekyError.unsupportedSource(url: url)
        }
    }
}
