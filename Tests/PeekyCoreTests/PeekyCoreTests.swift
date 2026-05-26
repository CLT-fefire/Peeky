import Testing
import Foundation
@testable import PeekyCore

@Suite("PeekyCore — 모델")
struct PeekyCoreTests {
    @Test("Inspection 초기화 — 빈 상태")
    func inspectionInit() {
        let url = URL(fileURLWithPath: "/tmp/Sample.app")
        let inspection = Inspection(source: .app(url))
        #expect(inspection.source == .app(url))
        #expect(inspection.bundle == nil)
        #expect(inspection.plugins.isEmpty)
    }
}

@Suite("ProfileDecoder — CMS 추출")
struct ProfileDecoderTests {
    @Test("빈 데이터는 디코드 실패")
    func emptyDataFails() {
        var thrown: Error?
        do {
            _ = try ProfileDecoder.extractPlistPayload(from: Data())
        } catch {
            thrown = error
        }
        #expect(thrown != nil)
    }

    @Test("랜덤 바이트는 CMS 디코드 실패")
    func randomBytesFails() {
        let junk = Data((0..<256).map { _ in UInt8.random(in: 0...255) })
        var thrown: Error?
        do {
            _ = try ProfileDecoder.extractPlistPayload(from: junk)
        } catch {
            thrown = error
        }
        #expect(thrown != nil)
    }

    /// 환경변수 `PEEKY_SAMPLE_PROFILE`이 지정되면 실제 `.mobileprovision`을 디코드해
    /// 표준 필드가 모두 추출되는지 검증한다. CI에서는 스킵.
    @Test("실제 .mobileprovision 디코드 (env-gated)")
    func realProfileDecode() throws {
        guard let path = ProcessInfo.processInfo.environment["PEEKY_SAMPLE_PROFILE"] else {
            print("SKIP: PEEKY_SAMPLE_PROFILE 환경변수 미설정")
            return
        }
        let url = URL(fileURLWithPath: path)
        let (profile, entitlements) = try ProfileDecoder.decode(at: url)

        #expect(profile.uuid != nil, "UUID 추출 실패")
        #expect(profile.name != nil, "Name 추출 실패")
        #expect(profile.expirationDate != nil, "ExpirationDate 추출 실패")
        #expect(!profile.teamIdentifier.isEmpty, "TeamIdentifier 추출 실패")

        print("✓ Name: \(profile.name ?? "?")")
        print("✓ UUID: \(profile.uuid ?? "?")")
        print("✓ Team: \(profile.teamName ?? "?") (\(profile.teamIdentifier.joined(separator: ", ")))")
        print("✓ Expires: \(profile.expirationDate?.description ?? "?")")
        print("✓ Devices: \(profile.devicesCount.map(String.init) ?? "all")")
        print("✓ Entitlements: \(entitlements?.raw.count ?? 0) keys")
    }
}
