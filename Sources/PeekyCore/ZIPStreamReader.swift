import Foundation
import Compression

/// `.ipa` (ZIP) 컨테이너에서 필요한 엔트리만 random-access로 추출한다.
///
/// 전체 압축 해제를 피하고 EOCD → Central Directory → 단일 엔트리 inflate 순으로
/// 동작하므로 QL 익스텐션 메모리 한도(약 120MB) 안에서 안전.
///
/// 지원: deflate(method 8), stored(method 0). ZIP64는 미지원.
public final class ZIPStreamReader {
    public struct Entry: Sendable {
        public let path: String
        public let compressedSize: UInt64
        public let uncompressedSize: UInt64
        public let compressionMethod: UInt16
        public let localHeaderOffset: UInt64
        public var isDirectory: Bool { path.hasSuffix("/") }
    }

    private let handle: FileHandle
    private let fileSize: UInt64
    public let entries: [Entry]

    public init(url: URL) throws {
        self.handle = try FileHandle(forReadingFrom: url)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        self.fileSize = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        self.entries = try Self.readCentralDirectory(from: handle, fileSize: fileSize)
    }

    deinit {
        try? handle.close()
    }

    /// 특정 엔트리의 압축 해제된 데이터를 메모리에 반환.
    public func read(_ entry: Entry) throws -> Data {
        try handle.seek(toOffset: entry.localHeaderOffset)
        let header = try handle.read(upToCount: 30) ?? Data()
        guard header.count == 30, header.read32(at: 0) == 0x04034b50 else {
            throw PeekyError.ipaExtractFailed(reason: "Local file header signature 불일치")
        }
        let nameLength = Int(header.read16(at: 26))
        let extraLength = Int(header.read16(at: 28))
        try handle.seek(toOffset: entry.localHeaderOffset + 30 + UInt64(nameLength + extraLength))
        let compressed = try handle.read(upToCount: Int(entry.compressedSize)) ?? Data()

        switch entry.compressionMethod {
        case 0: return compressed
        case 8: return try inflate(compressed, uncompressedSize: Int(entry.uncompressedSize))
        default:
            throw PeekyError.ipaExtractFailed(reason: "지원하지 않는 압축 방식: \(entry.compressionMethod)")
        }
    }

    /// 경로 패턴으로 첫 매칭 엔트리 검색. 와일드카드 미지원, 단순 prefix/suffix 매칭.
    public func first(where predicate: (Entry) -> Bool) -> Entry? {
        entries.first(where: predicate)
    }

    // MARK: - Central Directory parsing

    private static func readCentralDirectory(from handle: FileHandle, fileSize: UInt64) throws -> [Entry] {
        let eocd = try findEOCD(handle: handle, fileSize: fileSize)
        let cdSize = UInt64(eocd.read32(at: 12))
        let cdOffset = UInt64(eocd.read32(at: 16))
        guard cdSize > 0 else { return [] }

        try handle.seek(toOffset: cdOffset)
        guard let cdData = try handle.read(upToCount: Int(cdSize)) else {
            throw PeekyError.ipaExtractFailed(reason: "Central Directory 읽기 실패")
        }

        var entries: [Entry] = []
        var cursor = 0
        while cursor + 46 <= cdData.count {
            guard cdData.read32(at: cursor) == 0x02014b50 else { break }
            let compressionMethod = cdData.read16(at: cursor + 10)
            let compressedSize = UInt64(cdData.read32(at: cursor + 20))
            let uncompressedSize = UInt64(cdData.read32(at: cursor + 24))
            let nameLength = Int(cdData.read16(at: cursor + 28))
            let extraLength = Int(cdData.read16(at: cursor + 30))
            let commentLength = Int(cdData.read16(at: cursor + 32))
            let localHeaderOffset = UInt64(cdData.read32(at: cursor + 42))

            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= cdData.count else { break }
            let path = String(data: cdData.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? ""

            entries.append(Entry(
                path: path,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                compressionMethod: compressionMethod,
                localHeaderOffset: localHeaderOffset
            ))
            cursor = nameEnd + extraLength + commentLength
        }
        return entries
    }

    /// End-of-Central-Directory record를 파일 끝에서 역방향 탐색.
    /// EOCD는 가변 길이 comment(최대 64KB)를 가질 수 있어 최대 22 + 65535 바이트 윈도우.
    private static func findEOCD(handle: FileHandle, fileSize: UInt64) throws -> Data {
        let searchWindow = UInt64(22 + 0xFFFF)
        let readSize = min(searchWindow, fileSize)
        try handle.seek(toOffset: fileSize - readSize)
        guard let buffer = try handle.read(upToCount: Int(readSize)) else {
            throw PeekyError.ipaExtractFailed(reason: "EOCD 탐색 실패")
        }
        var i = buffer.count - 22
        while i >= 0 {
            if buffer.read32(at: i) == 0x06054b50 {
                let commentLength = Int(buffer.read16(at: i + 20))
                if i + 22 + commentLength <= buffer.count {
                    return buffer.subdata(in: i..<(i + 22))
                }
            }
            i -= 1
        }
        throw PeekyError.ipaExtractFailed(reason: "EOCD signature 미발견 — 손상된 ZIP")
    }

    // MARK: - Deflate

    private func inflate(_ compressed: Data, uncompressedSize: Int) throws -> Data {
        let bufferSize = max(uncompressedSize, 64 * 1024)
        var output = Data(count: bufferSize)
        let result = compressed.withUnsafeBytes { (srcBuf: UnsafeRawBufferPointer) -> Int in
            output.withUnsafeMutableBytes { (dstBuf: UnsafeMutableRawBufferPointer) -> Int in
                guard let src = srcBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dst = dstBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return compression_decode_buffer(dst, bufferSize, src, compressed.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard result > 0 else {
            throw PeekyError.ipaExtractFailed(reason: "deflate 해제 실패")
        }
        output.removeSubrange(result..<output.count)
        return output
    }
}

// MARK: - Data little-endian helpers

private extension Data {
    /// ZIP 포맷은 little-endian이고 필드가 비정렬 위치에 있을 수 있어 loadUnaligned 사용.
    func read32(at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress, offset + 4 <= ptr.count else { return }
            value = (base + offset).loadUnaligned(as: UInt32.self).littleEndian
        }
        return value
    }

    func read16(at offset: Int) -> UInt16 {
        var value: UInt16 = 0
        withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress, offset + 2 <= ptr.count else { return }
            value = (base + offset).loadUnaligned(as: UInt16.self).littleEndian
        }
        return value
    }
}
