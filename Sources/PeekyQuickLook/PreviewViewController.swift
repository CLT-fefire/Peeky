import AppKit
import QuickLookUI
import SwiftUI
import PeekyCore

/// Quick Look이 미리보기를 요청할 때 macOS가 인스턴스화하는 principal class.
/// Info.plist의 NSExtensionPrincipalClass = "PeekyQuickLook.PreviewViewController"에 매칭된다.
///
/// 주의: `@objc(PreviewViewController)` rename 금지. Swift runtime이 `Module.ClassName` 형태로
/// NSClassFromString 매칭을 처리하는데, 명시적 rename을 하면 모듈 prefix가 사라져 시스템이
/// 클래스를 못 찾아 익스텐션 초기화 실패 → pluginkit 등록 거부.
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
