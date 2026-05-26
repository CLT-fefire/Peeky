import Testing
import Foundation
@testable import PeekyCore

@Suite("IPAInspector — ZIP 메타데이터 추출")
struct IPAInspectorTests {
    @Test("합성 .ipa 검사 — 모든 필드 추출")
    func syntheticIPA() throws {
        let url = URL(fileURLWithPath: "/tmp/TestApp.ipa")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("SKIP: /tmp/TestApp.ipa 미생성")
            return
        }

        let inspection = try IPAInspector.inspect(ipaAt: url)

        #expect(inspection.bundle?.bundleIdentifier == "com.peeky.test")
        #expect(inspection.bundle?.displayName == "Peeky Test App")
        #expect(inspection.bundle?.shortVersion == "1.2.3")
        #expect(inspection.bundle?.buildVersion == "42")
        #expect(inspection.bundle?.minimumOSVersion == "15.0")
        #expect(inspection.profile != nil)
        #expect(inspection.plugins.count == 1)
        #expect(inspection.plugins.first?.extensionPointIdentifier == "com.apple.widgetkit-extension")

        print("✓ IPA Bundle: \(inspection.bundle?.bundleIdentifier ?? "?")")
        print("✓ IPA Version: \(inspection.bundle?.shortVersion ?? "?") (\(inspection.bundle?.buildVersion ?? "?"))")
        print("✓ IPA Min iOS: \(inspection.bundle?.minimumOSVersion ?? "?")")
        print("✓ Embedded Profile: \(inspection.profile?.name ?? "—")")
        print("✓ Profile Team: \(inspection.profile?.teamName ?? "—")")
        print("✓ Profile Expires: \(inspection.profile?.expirationDate?.description ?? "—")")
        print("✓ PlugIns: \(inspection.plugins.count)개")
        for plugin in inspection.plugins {
            print("    \(plugin.url.lastPathComponent) → \(plugin.extensionPointIdentifier ?? "-") (\(plugin.bundleIdentifier ?? "?"))")
        }
        print("✓ Warnings: \(inspection.warnings.count)")
    }

    @Test("ZIPStreamReader — TestApp.ipa 엔트리 열거")
    func zipEntryEnumeration() throws {
        let url = URL(fileURLWithPath: "/tmp/TestApp.ipa")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let zip = try ZIPStreamReader(url: url)
        #expect(!zip.entries.isEmpty)
        print("✓ ZIP entries: \(zip.entries.count)")
        for entry in zip.entries.prefix(10) {
            print("    \(entry.path) (\(entry.uncompressedSize) → \(entry.compressedSize) bytes, method=\(entry.compressionMethod))")
        }
    }
}
