import Foundation

/// `.ipa` ZIP 파일에서 필요한 엔트리만 스트리밍 방식으로 추출한다.
/// QL 익스텐션 메모리 한도(약 120MB)를 고려해 전체 압축 해제는 피한다.
/// Phase 6에서 central directory parser + per-entry inflater를 구현한다.
public enum ZIPStreamReader {
    public static func listEntries(at url: URL) throws -> [Entry] {
        // Phase 6에서 central directory parse 구현. 스켈레톤은 빈 배열.
        return []
    }

    public struct Entry: Sendable {
        public let path: String
        public let uncompressedSize: UInt64
        public let isDirectory: Bool
    }
}
