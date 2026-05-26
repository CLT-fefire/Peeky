import Foundation
import Security

/// `SecStaticCode*` 패밀리를 감싸 서명 정보, 인증서 체인, entitlements를 추출한다.
public enum SignatureReader {
    /// 번들 하나의 서명 정보를 읽는다.
    /// - Returns: `(SigningInfo?, Entitlements?)`. 서명 없음(unsigned)이면 둘 다 nil.
    public static func read(bundleAt url: URL) -> (SigningInfo?, Entitlements?) {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else {
            return (nil, nil)
        }

        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation)
        let infoStatus = SecCodeCopySigningInformation(code, flags, &info)
        guard infoStatus == errSecSuccess, let dict = info as? [String: Any] else {
            return (nil, nil)
        }

        let identifier = dict[kSecCodeInfoIdentifier as String] as? String
        let teamID = dict[kSecCodeInfoTeamIdentifier as String] as? String
        let entitlementsDict = dict[kSecCodeInfoEntitlementsDict as String] as? [String: Any]

        // kSecCodeSignatureAdhoc = 1 << 1 = 0x2 (Security/SecCode.h)
        // Swift Foundation overlay에 노출되지 않아 raw value 사용.
        let adHocFlag: UInt32 = 0x0000_0002
        let isAdHoc = (dict[kSecCodeInfoFlags as String] as? UInt32).map { $0 & adHocFlag != 0 } ?? false

        let certificateChain = readCertificateChain(from: dict)
        let signingIdentity = certificateChain.first?.commonName

        let signing = SigningInfo(
            identifier: identifier,
            teamIdentifier: teamID,
            signingIdentity: signingIdentity,
            certificateChain: certificateChain,
            isAdHoc: isAdHoc
        )
        let entitlements = entitlementsDict.map { Entitlements(raw: $0) }
        return (signing, entitlements)
    }

    /// `kSecCodeInfoCertificates`는 `CFArray<SecCertificate>` — leaf 부터 root 순서.
    private static func readCertificateChain(from dict: [String: Any]) -> [SigningInfo.Certificate] {
        guard let raw = dict[kSecCodeInfoCertificates as String] else { return [] }
        let array = raw as! CFArray
        let count = CFArrayGetCount(array)
        var result: [SigningInfo.Certificate] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let value = CFArrayGetValueAtIndex(array, i)
            let cert = Unmanaged<SecCertificate>.fromOpaque(value!).takeUnretainedValue()
            result.append(parseCertificate(cert))
        }
        return result
    }

    private static func parseCertificate(_ cert: SecCertificate) -> SigningInfo.Certificate {
        let commonName = copyCommonName(of: cert) ?? "Unknown"
        let (organization, notBefore, notAfter) = copyCertificateDetails(of: cert)
        return SigningInfo.Certificate(
            commonName: commonName,
            organization: organization,
            notBefore: notBefore,
            notAfter: notAfter
        )
    }

    private static func copyCommonName(of cert: SecCertificate) -> String? {
        var cn: CFString?
        let status = SecCertificateCopyCommonName(cert, &cn)
        guard status == errSecSuccess else { return nil }
        return cn as String?
    }

    /// X.509 인증서에서 Organization, validity 기간을 추출. `SecCertificateCopyValues`는
    /// OID dictionary를 반환하며 각 항목은 `kSecPropertyKeyValue`에 실제 값을 둔다.
    private static func copyCertificateDetails(of cert: SecCertificate) -> (org: String?, notBefore: Date?, notAfter: Date?) {
        let oids: [CFString] = [
            kSecOIDX509V1SubjectName,
            kSecOIDX509V1ValidityNotBefore,
            kSecOIDX509V1ValidityNotAfter,
        ]
        let keys = oids as CFArray
        var error: Unmanaged<CFError>?
        guard let valuesRef = SecCertificateCopyValues(cert, keys, &error) else {
            return (nil, nil, nil)
        }
        let values = valuesRef as! [CFString: Any]

        let org = extractSubjectOrganization(from: values)
        let notBefore = extractValidityDate(from: values, oid: kSecOIDX509V1ValidityNotBefore)
        let notAfter = extractValidityDate(from: values, oid: kSecOIDX509V1ValidityNotAfter)
        return (org, notBefore, notAfter)
    }

    private static func extractSubjectOrganization(from values: [CFString: Any]) -> String? {
        guard let entry = values[kSecOIDX509V1SubjectName] as? [CFString: Any],
              let propValue = entry[kSecPropertyKeyValue] as? [[CFString: Any]] else {
            return nil
        }
        for item in propValue {
            if let label = item[kSecPropertyKeyLabel] as? String,
               label == (kSecOIDOrganizationName as String),
               let value = item[kSecPropertyKeyValue] as? String {
                return value
            }
        }
        return nil
    }

    private static func extractValidityDate(from values: [CFString: Any], oid: CFString) -> Date? {
        guard let entry = values[oid] as? [CFString: Any],
              let interval = entry[kSecPropertyKeyValue] as? NSNumber else {
            return nil
        }
        // X.509 인증서 날짜는 CFAbsoluteTime (2001-01-01 기준).
        return Date(timeIntervalSinceReferenceDate: interval.doubleValue)
    }
}
