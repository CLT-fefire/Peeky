import Testing
import Foundation
@testable import PeekyCore

@Suite("XCArchiveInspector — .xcarchive 검사")
struct XCArchiveInspectorTests {
    @Test("합성 xcarchive — Archive 메타 + 내부 .app 재귀 검사")
    func syntheticArchive() throws {
        let url = URL(fileURLWithPath: "/tmp/TestArchive.xcarchive")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("SKIP: /tmp/TestArchive.xcarchive 미생성")
            return
        }

        let inspection = try XCArchiveInspector.inspect(archiveAt: url)
        let archive = inspection.archive!

        #expect(archive.schemeName == "Peeky")
        #expect(archive.archiveVersion == 2)
        #expect(archive.teamIdentifier == "2MVJL2VUTF")
        #expect(archive.applicationPath == "Applications/Peeky.app")
        #expect(archive.dSYMCount == 3)

        // 재귀 검사 결과 — 내부 .app의 bundle/signing 정보가 채워져야 함
        #expect(inspection.bundle?.bundleIdentifier == "com.local.peeky")
        #expect(inspection.signing != nil)
        #expect(inspection.plugins.count == 1)  // PeekyQuickLook.appex

        print("━━━━━ Archive ━━━━━")
        print("  Scheme: \(archive.schemeName ?? "?")")
        print("  Created: \(archive.creationDate?.description ?? "?")")
        print("  Archive v.: \(archive.archiveVersion ?? -1)")
        print("  Signing: \(archive.signingIdentity ?? "?")")
        print("  Team: \(archive.teamIdentifier ?? "?")")
        print("  App Path: \(archive.applicationPath ?? "?")")
        print("  dSYMs: \(archive.dSYMCount)")
        print("━━━━━ Inner .app ━━━━━")
        print("  Bundle: \(inspection.bundle?.bundleIdentifier ?? "?")")
        print("  Signing: \(inspection.signing?.signingIdentity ?? "?")")
        print("  Cert chain: \(inspection.signing?.certificateChain.count ?? 0)")
        print("  PlugIns: \(inspection.plugins.count) (\(inspection.plugins.map { $0.url.deletingPathExtension().lastPathComponent }.joined(separator: ", ")))")
    }
}
