import Foundation

/// `.xcarchive` 디렉토리 번들을 검사한다.
///
/// 표준 구조:
/// ```
/// MyApp.xcarchive/
/// ├── Info.plist                 # archive 메타 (ApplicationProperties, CreationDate, SchemeName)
/// ├── Products/Applications/MyApp.app/   # 실제 앱 → BundleInspector로 재귀
/// ├── dSYMs/*.dSYM/              # 심볼 파일들 (presence/count만 확인)
/// └── SwiftSupport/              # AppStore 제출용 Swift 런타임 (선택)
/// ```
public enum XCArchiveInspector {
    public static func inspect(archiveAt url: URL) throws -> Inspection {
        let archiveInfo = try readArchiveInfo(at: url)
        let appURL = locateAppBundle(in: url, hintedPath: archiveInfo.applicationPath)

        var bundle: BundleInfo?
        var signing: SigningInfo?
        var profile: ProvisioningProfile?
        var entitlements: Entitlements?
        var plugins: [BundleInfo] = []
        var warnings: [String] = []

        if let appURL {
            do {
                let inner = try BundleInspector.inspect(bundleAt: appURL)
                bundle = inner.bundle
                signing = inner.signing
                profile = inner.profile
                entitlements = inner.entitlements
                plugins = inner.plugins
                warnings.append(contentsOf: inner.warnings)
            } catch {
                warnings.append("내부 .app 검사 실패: \(error)")
            }
        } else {
            warnings.append("Products/Applications/*.app 미발견")
        }

        return Inspection(
            source: .xcarchive(url),
            bundle: bundle,
            signing: signing,
            profile: profile,
            entitlements: entitlements,
            plugins: plugins,
            archive: archiveInfo,
            warnings: warnings
        )
    }

    private static func readArchiveInfo(at url: URL) throws -> ArchiveInfo {
        let plistURL = url.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw PeekyError.invalidPlist(url: plistURL)
        }
        let data = try Data(contentsOf: plistURL)
        guard let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw PeekyError.invalidPlist(url: plistURL)
        }
        let appProps = dict["ApplicationProperties"] as? [String: Any]

        return ArchiveInfo(
            creationDate: dict["CreationDate"] as? Date,
            schemeName: dict["SchemeName"] as? String,
            name: dict["Name"] as? String,
            archiveVersion: (dict["ArchiveVersion"] as? NSNumber)?.intValue,
            signingIdentity: appProps?["SigningIdentity"] as? String,
            teamIdentifier: appProps?["Team"] as? String,
            applicationPath: appProps?["ApplicationPath"] as? String,
            dSYMCount: countDSYMs(in: url)
        )
    }

    private static func locateAppBundle(in archiveURL: URL, hintedPath: String?) -> URL? {
        let fm = FileManager.default

        // 1. Info.plist ApplicationPath 힌트 (`Applications/MyApp.app`)
        if let hint = hintedPath {
            let candidate = archiveURL.appendingPathComponent("Products").appendingPathComponent(hint)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // 2. 표준 위치 `Products/Applications/*.app` 첫 매치
        let standard = archiveURL.appendingPathComponent("Products/Applications")
        if let entries = try? fm.contentsOfDirectory(at: standard, includingPropertiesForKeys: nil),
           let firstApp = entries.first(where: { $0.pathExtension == "app" }) {
            return firstApp
        }
        return nil
    }

    private static func countDSYMs(in archiveURL: URL) -> Int {
        let dSYMsDir = archiveURL.appendingPathComponent("dSYMs")
        guard let entries = try? FileManager.default.contentsOfDirectory(at: dSYMsDir, includingPropertiesForKeys: nil) else {
            return 0
        }
        return entries.filter { $0.pathExtension == "dSYM" }.count
    }
}
