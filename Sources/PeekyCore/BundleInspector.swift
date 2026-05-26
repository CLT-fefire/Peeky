import Foundation

/// .app / .appex / .xcarchive 등 디스크상의 번들을 읽어 `BundleInfo`를 만든다.
/// Phase 0 스켈레톤 — Phase 2에서 실제 파싱 로직을 채운다.
public enum BundleInspector {
    public static func inspectAppBundle(at url: URL) throws -> BundleInfo {
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        let iosInfoPlistURL = url.appendingPathComponent("Info.plist")
        let plistURL = FileManager.default.fileExists(atPath: infoPlistURL.path) ? infoPlistURL : iosInfoPlistURL
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

    public static func listPlugins(in appBundleURL: URL) -> [URL] {
        let candidates = [
            appBundleURL.appendingPathComponent("Contents/PlugIns"),
            appBundleURL.appendingPathComponent("PlugIns"),
        ]
        let fm = FileManager.default
        for dir in candidates where fm.fileExists(atPath: dir.path) {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            return entries.filter { $0.pathExtension == "appex" }
        }
        return []
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

public enum PeekyError: Error, Sendable {
    case invalidPlist(url: URL)
    case unsupportedSource(url: URL)
    case profileDecodeFailed(reason: String)
    case ipaExtractFailed(reason: String)
}
