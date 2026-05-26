import Foundation
import Security

/// `SecStaticCode*` 패밀리를 감싸 서명 정보, 인증서 체인, entitlements를 추출한다.
/// Phase 3에서 실제 구현을 채운다.
public enum SignatureReader {
    public static func read(bundleAt url: URL) throws -> (SigningInfo, Entitlements?) {
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard status == errSecSuccess, let code = staticCode else {
            throw PeekyError.unsupportedSource(url: url)
        }

        var info: CFDictionary?
        let flags: SecCSFlags = SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation)
        let infoStatus = SecCodeCopySigningInformation(code, flags, &info)
        guard infoStatus == errSecSuccess, let dict = info as? [String: Any] else {
            return (SigningInfo(isAdHoc: true), nil)
        }

        let identifier = dict[kSecCodeInfoIdentifier as String] as? String
        let teamID = dict[kSecCodeInfoTeamIdentifier as String] as? String
        let entitlementsDict = dict[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        // kSecCodeSignatureAdhoc = 1 << 1 = 2 (Security/SecCode.h, Swift import 누락)
        let adHocFlag: UInt32 = 0x0000_0002
        let isAdHoc = (dict[kSecCodeInfoFlags as String] as? UInt32).map { $0 & adHocFlag != 0 } ?? false

        let signing = SigningInfo(
            identifier: identifier,
            teamIdentifier: teamID,
            signingIdentity: nil,
            certificateChain: [],
            isAdHoc: isAdHoc
        )
        let entitlements = entitlementsDict.map { Entitlements(raw: $0) }
        return (signing, entitlements)
    }
}
