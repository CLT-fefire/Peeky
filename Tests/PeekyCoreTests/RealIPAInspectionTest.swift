import Testing
import Foundation
@testable import PeekyCore

@Suite("실전 IPA 검사")
struct RealIPAInspectionTest {
    /// 환경변수 `PEEKY_REAL_IPA`로 실제 회사 QA IPA 검사.
    @Test("회사 QA IPA 검사 (env-gated)")
    func realIPA() throws {
        guard let path = ProcessInfo.processInfo.environment["PEEKY_REAL_IPA"] else {
            print("SKIP: PEEKY_REAL_IPA 미설정")
            return
        }
        let url = URL(fileURLWithPath: path)
        let inspection = try IPAInspector.inspect(ipaAt: url)

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📦 \(url.lastPathComponent)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        if let b = inspection.bundle {
            print("\n[ Bundle ]")
            print("  Identifier:    \(b.bundleIdentifier ?? "?")")
            print("  Display Name:  \(b.displayName ?? "?")")
            print("  Executable:    \(b.executableName ?? "?")")
            print("  Version:       \(b.shortVersion ?? "?") (\(b.buildVersion ?? "?"))")
            print("  Min iOS:       \(b.minimumOSVersion ?? "?")")
            print("  Platforms:     \(b.platforms.joined(separator: ", "))")
        }

        if let p = inspection.profile {
            print("\n[ Provisioning Profile ]")
            print("  Name:          \(p.name ?? "?")")
            print("  UUID:          \(p.uuid ?? "?")")
            print("  AppID Name:    \(p.appIDName ?? "?")")
            print("  Team:          \(p.teamName ?? "?") (\(p.teamIdentifier.joined(separator: ", ")))")
            print("  Created:       \(p.creationDate?.description ?? "?")")
            print("  Expires:       \(p.expirationDate?.description ?? "?")")
            print("  Devices:       \(p.devicesCount.map(String.init) ?? "all")")
            print("  Platform:      \(p.platform.joined(separator: ", "))")
        }

        if let e = inspection.entitlements {
            print("\n[ Entitlements (\(e.raw.count)) ]")
            for key in e.raw.keys.sorted() {
                let value = e.raw[key].map { String(describing: $0) } ?? "—"
                let trimmed = value.count > 80 ? String(value.prefix(80)) + "…" : value
                print("  \(key)")
                print("    = \(trimmed)")
            }
        }

        if !inspection.plugins.isEmpty {
            print("\n[ Embedded Extensions (\(inspection.plugins.count)) ]")
            for plugin in inspection.plugins {
                print("  • \(plugin.url.deletingLastPathComponent().lastPathComponent)")
                print("    Bundle ID: \(plugin.bundleIdentifier ?? "?")")
                print("    Extension: \(plugin.extensionPointIdentifier ?? "?")")
                print("    Principal: \(plugin.extensionPrincipalClass ?? "?")")
            }
        }

        if !inspection.warnings.isEmpty {
            print("\n[ Notes ]")
            for w in inspection.warnings { print("  ⓘ \(w)") }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        #expect(inspection.bundle?.bundleIdentifier != nil)
    }
}
