import Foundation

/// `.app` / `.appex` / `.xcarchive` 등 디스크상의 번들을 검사한다.
public enum BundleInspector {
    /// 번들 하나를 완전히 검사해 `Inspection` 트리를 만든다.
    ///
    /// - Parameter url: `.app` 또는 `.appex` 번들의 루트 디렉토리.
    /// - Parameter recurseIntoPlugins: true면 `Contents/PlugIns/*.appex`를 재귀 검사.
    public static func inspect(bundleAt url: URL, recurseIntoPlugins: Bool = true) throws -> Inspection {
        let info = try readBundleInfo(at: url)
        let (profile, profileEntitlements) = readEmbeddedProfile(in: url)
        let warnings = profile == nil
            ? (hasEmbeddedProfileSlot(in: url) ? ["임베디드 프로파일 디코드 실패"] : [])
            : []

        let pluginInfos: [BundleInfo] = recurseIntoPlugins
            ? listPlugins(in: url).compactMap { try? readBundleInfo(at: $0) }
            : []

        let source: Inspection.Source = url.pathExtension.lowercased() == "appex" ? .appex(url) : .app(url)

        return Inspection(
            source: source,
            bundle: info,
            signing: nil,
            profile: profile,
            entitlements: profileEntitlements,
            plugins: pluginInfos,
            warnings: warnings
        )
    }

    /// `.app` / `.appex`의 `Info.plist`를 읽어 `BundleInfo`로 변환.
    public static func readBundleInfo(at url: URL) throws -> BundleInfo {
        let plistURL = locateInfoPlist(in: url)
        let plist = try readPlist(at: plistURL)

        return BundleInfo(
            url: url,
            bundleIdentifier: plist["CFBundleIdentifier"] as? String,
            displayName: (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String),
            executableName: plist["CFBundleExecutable"] as? String,
            shortVersion: plist["CFBundleShortVersionString"] as? String,
            buildVersion: plist["CFBundleVersion"] as? String,
            minimumOSVersion: (plist["MinimumOSVersion"] as? String) ?? (plist["LSMinimumSystemVersion"] as? String),
            platforms: plist["CFBundleSupportedPlatforms"] as? [String] ?? [],
            extensionPointIdentifier: nsExtensionPointIdentifier(from: plist),
            extensionPrincipalClass: nsExtensionPrincipalClass(from: plist)
        )
    }

    /// `Contents/PlugIns/*.appex` URL 목록.
    public static func listPlugins(in appBundleURL: URL) -> [URL] {
        let candidates = [
            appBundleURL.appendingPathComponent("Contents/PlugIns"),
            appBundleURL.appendingPathComponent("PlugIns"),
        ]
        let fm = FileManager.default
        for dir in candidates where fm.fileExists(atPath: dir.path) {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            return entries
                .filter { $0.pathExtension == "appex" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        return []
    }

    /// 번들 안 임베디드 프로비저닝 프로파일을 찾아 디코드.
    /// 위치 규칙:
    /// - macOS `.app`: `Contents/embedded.provisionprofile`
    /// - iOS `.app`: `embedded.mobileprovision` (번들 루트)
    /// - macOS/iOS `.appex`: 위와 동일 위치를 부모 .app 기준으로 사용
    public static func readEmbeddedProfile(in bundleURL: URL) -> (ProvisioningProfile?, Entitlements?) {
        let fm = FileManager.default
        let candidates = [
            bundleURL.appendingPathComponent("Contents/embedded.provisionprofile"),
            bundleURL.appendingPathComponent("embedded.mobileprovision"),
            bundleURL.appendingPathComponent("Contents/embedded.mobileprovision"),
        ]
        for candidate in candidates where fm.fileExists(atPath: candidate.path) {
            if let result = try? ProfileDecoder.decode(at: candidate) {
                return result
            }
        }
        return (nil, nil)
    }

    /// `Info.plist`가 macOS 번들(`Contents/Info.plist`) 또는
    /// iOS 번들(루트 `Info.plist`) 어느 쪽인지 자동 판별.
    private static func locateInfoPlist(in bundleURL: URL) -> URL {
        let macStyle = bundleURL.appendingPathComponent("Contents/Info.plist")
        let iosStyle = bundleURL.appendingPathComponent("Info.plist")
        return FileManager.default.fileExists(atPath: macStyle.path) ? macStyle : iosStyle
    }

    /// 프로파일 파일이 존재했는지 (디코드 실패와 부재를 구분하기 위해).
    private static func hasEmbeddedProfileSlot(in bundleURL: URL) -> Bool {
        let fm = FileManager.default
        let candidates = [
            "Contents/embedded.provisionprofile",
            "embedded.mobileprovision",
            "Contents/embedded.mobileprovision",
        ]
        return candidates.contains { fm.fileExists(atPath: bundleURL.appendingPathComponent($0).path) }
    }

    private static func readPlist(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plist as? [String: Any] else {
            throw PeekyError.invalidPlist(url: url)
        }
        return dict
    }

    private static func nsExtensionPointIdentifier(from plist: [String: Any]) -> String? {
        (plist["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String
    }

    private static func nsExtensionPrincipalClass(from plist: [String: Any]) -> String? {
        (plist["NSExtension"] as? [String: Any])?["NSExtensionPrincipalClass"] as? String
    }
}

// MARK: - Backward-compat shim (Phase 0 호환)

public extension BundleInspector {
    @available(*, deprecated, renamed: "readBundleInfo(at:)")
    static func inspectAppBundle(at url: URL) throws -> BundleInfo {
        try readBundleInfo(at: url)
    }
}
