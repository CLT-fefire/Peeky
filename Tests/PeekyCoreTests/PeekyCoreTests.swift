import Testing
import Foundation
@testable import PeekyCore

@Suite("PeekyCore — 스켈레톤")
struct PeekyCoreTests {
    @Test("Inspection 모델 초기화")
    func inspectionInit() {
        let url = URL(fileURLWithPath: "/tmp/Sample.app")
        let inspection = Inspection(source: .app(url))
        #expect(inspection.source == .app(url))
        #expect(inspection.bundle == nil)
    }
}
