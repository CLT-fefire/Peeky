import Testing
import Foundation
@testable import PeekyCore

@Suite("BundleInspector — 실제 macOS 앱")
struct BundleInspectorTests {
    /// `/System/Applications/Notes.app` — 시스템 기본 앱, PlugIns 다수.
    @Test("Notes.app 검사 — Bundle ID + PlugIns")
    func notesApp() throws {
        let url = URL(fileURLWithPath: "/System/Applications/Notes.app")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("SKIP: Notes.app 없음")
            return
        }
        let inspection = try BundleInspector.inspect(bundleAt: url)
        #expect(inspection.bundle?.bundleIdentifier == "com.apple.Notes")
        #expect(inspection.bundle?.displayName != nil)
        print("✓ Notes Bundle ID: \(inspection.bundle?.bundleIdentifier ?? "?")")
        print("✓ Notes Version: \(inspection.bundle?.shortVersion ?? "?") (\(inspection.bundle?.buildVersion ?? "?"))")
        print("✓ Notes PlugIns: \(inspection.plugins.count)개")
        for plugin in inspection.plugins.prefix(5) {
            print("    \(plugin.url.deletingPathExtension().lastPathComponent) → \(plugin.extensionPointIdentifier ?? "-")")
        }
    }

    /// `/System/Library/CoreServices/Finder.app` — PlugIns가 거의 없는 시스템 앱.
    @Test("Finder.app 검사")
    func finderApp() throws {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("SKIP: Finder.app 없음")
            return
        }
        let inspection = try BundleInspector.inspect(bundleAt: url)
        #expect(inspection.bundle?.bundleIdentifier == "com.apple.finder")
        print("✓ Finder: \(inspection.bundle?.bundleIdentifier ?? "?")")
        print("✓ Finder PlugIns: \(inspection.plugins.count)개")
    }

    /// 환경변수 `PEEKY_SAMPLE_APP`이 지정되면 임의의 .app을 검사한다.
    @Test("임의 .app 검사 (env-gated)")
    func customApp() throws {
        guard let path = ProcessInfo.processInfo.environment["PEEKY_SAMPLE_APP"] else {
            print("SKIP: PEEKY_SAMPLE_APP 미설정")
            return
        }
        let url = URL(fileURLWithPath: path)
        let inspection = try BundleInspector.inspect(bundleAt: url)

        print("✓ Bundle ID: \(inspection.bundle?.bundleIdentifier ?? "?")")
        print("✓ Display Name: \(inspection.bundle?.displayName ?? "?")")
        print("✓ Version: \(inspection.bundle?.shortVersion ?? "?")")
        print("✓ Min OS: \(inspection.bundle?.minimumOSVersion ?? "?")")
        print("✓ Profile: \(inspection.profile?.name ?? "—")")
        print("✓ Team: \(inspection.profile?.teamName ?? "—")")
        print("✓ Entitlements: \(inspection.entitlements?.raw.count ?? 0) keys")
        print("✓ PlugIns: \(inspection.plugins.count)개")
        for plugin in inspection.plugins {
            print("    \(plugin.url.deletingPathExtension().lastPathComponent) → \(plugin.extensionPointIdentifier ?? "-")")
        }
    }
}
