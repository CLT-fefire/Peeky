import Foundation
import Security

/// `.mobileprovision` / `.provisionprofile` 파일을 디코드한다.
/// 두 파일 모두 CMS(PKCS#7) signed data 컨테이너이며 payload는 plist.
/// Phase 1에서 실제 구현을 채운다.
public enum ProfileDecoder {
    public static func decode(at url: URL) throws -> ProvisioningProfile {
        let data = try Data(contentsOf: url)
        let plistData = try extractPlistPayload(from: data)
        let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
        guard let dict = plist as? [String: Any] else {
            throw PeekyError.profileDecodeFailed(reason: "plist payload가 dictionary가 아님")
        }
        return ProvisioningProfile(
            uuid: dict["UUID"] as? String,
            name: dict["Name"] as? String,
            appIDName: dict["AppIDName"] as? String,
            teamName: dict["TeamName"] as? String,
            teamIdentifier: dict["TeamIdentifier"] as? [String] ?? [],
            creationDate: dict["CreationDate"] as? Date,
            expirationDate: dict["ExpirationDate"] as? Date,
            devicesCount: (dict["ProvisionedDevices"] as? [String])?.count,
            provisionsAllDevices: (dict["ProvisionsAllDevices"] as? Bool) ?? false,
            platform: dict["Platform"] as? [String] ?? []
        )
    }

    /// CMS signed data에서 plist payload만 분리. Phase 1에서 `CMSDecoder` 기반으로 정식 구현.
    /// 스켈레톤은 `<?xml ... ?>` ~ `</plist>` 사이를 바이트 스캔으로 추출.
    static func extractPlistPayload(from data: Data) throws -> Data {
        let openTag = Data("<?xml".utf8)
        let closeTag = Data("</plist>".utf8)
        guard let start = data.range(of: openTag)?.lowerBound,
              let end = data.range(of: closeTag, in: start..<data.endIndex)?.upperBound else {
            throw PeekyError.profileDecodeFailed(reason: "plist payload 범위를 찾지 못함")
        }
        return data.subdata(in: start..<end)
    }
}
