import Foundation
import Security

/// `.mobileprovision` / `.provisionprofile` 파일을 디코드한다.
///
/// 두 확장자 모두 동일하게 CMS(PKCS#7) signed data 컨테이너이며,
/// payload는 Apple의 프로비저닝 정보를 담은 XML plist다.
public enum ProfileDecoder {
    public static func decode(at url: URL) throws -> (profile: ProvisioningProfile, entitlements: Entitlements?) {
        let data = try Data(contentsOf: url)
        let plistData = try extractPlistPayload(from: data)
        let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
        guard let dict = plist as? [String: Any] else {
            throw PeekyError.profileDecodeFailed(reason: "plist payload가 dictionary가 아님")
        }

        let profile = ProvisioningProfile(
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

        let entitlements = (dict["Entitlements"] as? [String: Any]).map(Entitlements.init(raw:))
        return (profile, entitlements)
    }

    /// CMS(PKCS#7) signed data 컨테이너에서 inner content (plist payload) 추출.
    /// `Security.CMSDecoder` API를 사용 — `security cms -D -i file.mobileprovision` 와 동일 결과.
    static func extractPlistPayload(from data: Data) throws -> Data {
        var decoder: CMSDecoder?
        var status = CMSDecoderCreate(&decoder)
        guard status == errSecSuccess, let decoder else {
            throw PeekyError.profileDecodeFailed(reason: "CMSDecoderCreate failed (status=\(status))")
        }

        status = data.withUnsafeBytes { bytes -> OSStatus in
            guard let base = bytes.baseAddress else { return errSecParam }
            return CMSDecoderUpdateMessage(decoder, base, bytes.count)
        }
        guard status == errSecSuccess else {
            throw PeekyError.profileDecodeFailed(reason: "CMSDecoderUpdateMessage failed (status=\(status))")
        }

        status = CMSDecoderFinalizeMessage(decoder)
        guard status == errSecSuccess else {
            throw PeekyError.profileDecodeFailed(reason: "CMSDecoderFinalizeMessage failed (status=\(status))")
        }

        var contentRef: CFData?
        status = CMSDecoderCopyContent(decoder, &contentRef)
        guard status == errSecSuccess, let content = contentRef else {
            throw PeekyError.profileDecodeFailed(reason: "CMSDecoderCopyContent failed (status=\(status))")
        }
        return content as Data
    }
}
