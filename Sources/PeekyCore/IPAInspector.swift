import Foundation

/// `.ipa` 파일을 디스크 추출 없이 메타데이터만 빠르게 검사한다.
///
/// 추출 대상:
/// - `Payload/AppName.app/Info.plist` → `BundleInfo`
/// - `Payload/AppName.app/embedded.mobileprovision` → `ProvisioningProfile` + Entitlements
/// - `Payload/AppName.app/PlugIns/*.appex/Info.plist` → 임베디드 익스텐션 리스트
///
/// 코드사인 정보는 binary 추출이 필요해 제공하지 않는다 (UI에서 안내).
public enum IPAInspector {
    public static func inspect(ipaAt url: URL) throws -> Inspection {
        let zip = try ZIPStreamReader(url: url)

        guard let appRoot = detectAppRoot(in: zip.entries) else {
            throw PeekyError.ipaExtractFailed(reason: "Payload/*.app 디렉토리를 찾지 못함")
        }

        // 1. Info.plist
        let bundleInfo = try readBundleInfo(from: zip, appRoot: appRoot, bundleURL: url)

        // 2. embedded.mobileprovision
        let (profile, profileEntitlements) = readEmbeddedProfile(from: zip, appRoot: appRoot)

        // 3. PlugIns 열거
        let plugins = readPlugins(from: zip, appRoot: appRoot, parentURL: url)

        var warnings = ["IPA 메타데이터 모드 — 코드 서명 정보는 .app 추출 후 확인 가능"]
        if profile == nil, hasEmbeddedProfileSlot(from: zip, appRoot: appRoot) {
            warnings.append("임베디드 프로파일 디코드 실패")
        }

        return Inspection(
            source: .ipa(url),
            bundle: bundleInfo,
            signing: nil,
            profile: profile,
            entitlements: profileEntitlements,
            plugins: plugins,
            warnings: warnings
        )
    }

    /// `Payload/SomeApp.app/` 형태의 루트 prefix를 찾는다.
    private static func detectAppRoot(in entries: [ZIPStreamReader.Entry]) -> String? {
        for entry in entries {
            let components = entry.path.split(separator: "/", omittingEmptySubsequences: false)
            if components.count >= 2,
               components[0] == "Payload",
               components[1].hasSuffix(".app") {
                return "Payload/\(components[1])/"
            }
        }
        return nil
    }

    private static func readBundleInfo(
        from zip: ZIPStreamReader,
        appRoot: String,
        bundleURL: URL
    ) throws -> BundleInfo? {
        let plistPath = appRoot + "Info.plist"
        guard let entry = zip.first(where: { $0.path == plistPath }) else { return nil }
        let data = try zip.read(entry)
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        return BundleInfo(
            url: bundleURL,
            bundleIdentifier: plist["CFBundleIdentifier"] as? String,
            displayName: (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String),
            executableName: plist["CFBundleExecutable"] as? String,
            shortVersion: plist["CFBundleShortVersionString"] as? String,
            buildVersion: plist["CFBundleVersion"] as? String,
            minimumOSVersion: (plist["MinimumOSVersion"] as? String) ?? (plist["LSMinimumSystemVersion"] as? String),
            platforms: plist["CFBundleSupportedPlatforms"] as? [String] ?? [],
            extensionPointIdentifier: nil,
            extensionPrincipalClass: nil
        )
    }

    private static func readEmbeddedProfile(
        from zip: ZIPStreamReader,
        appRoot: String
    ) -> (ProvisioningProfile?, Entitlements?) {
        let candidates = [
            appRoot + "embedded.mobileprovision",
            appRoot + "Contents/embedded.provisionprofile",
        ]
        for path in candidates {
            guard let entry = zip.first(where: { $0.path == path }),
                  let data = try? zip.read(entry) else { continue }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("peeky-\(UUID().uuidString).profile")
            defer { try? FileManager.default.removeItem(at: tempURL) }
            do {
                try data.write(to: tempURL)
                let (profile, entitlements) = try ProfileDecoder.decode(at: tempURL)
                return (profile, entitlements)
            } catch {
                continue
            }
        }
        return (nil, nil)
    }

    private static func hasEmbeddedProfileSlot(from zip: ZIPStreamReader, appRoot: String) -> Bool {
        let candidates = [
            appRoot + "embedded.mobileprovision",
            appRoot + "Contents/embedded.provisionprofile",
        ]
        return candidates.contains { path in
            zip.first(where: { $0.path == path }) != nil
        }
    }

    /// `appRoot/PlugIns/*.appex/Info.plist` 별로 BundleInfo 생성.
    /// .ipa는 URL이 zip 내부 가상 경로이므로 부모 .ipa URL + path fragment로 표시.
    private static func readPlugins(
        from zip: ZIPStreamReader,
        appRoot: String,
        parentURL: URL
    ) -> [BundleInfo] {
        let pluginsRoot = appRoot + "PlugIns/"
        var pluginNames = Set<String>()
        for entry in zip.entries where entry.path.hasPrefix(pluginsRoot) {
            let rest = String(entry.path.dropFirst(pluginsRoot.count))
            if let firstSlash = rest.firstIndex(of: "/") {
                let name = String(rest[..<firstSlash])
                if name.hasSuffix(".appex") {
                    pluginNames.insert(name)
                }
            }
        }

        return pluginNames.sorted().compactMap { name -> BundleInfo? in
            let plistPath = "\(pluginsRoot)\(name)/Info.plist"
            guard let entry = zip.first(where: { $0.path == plistPath }),
                  let data = try? zip.read(entry),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                return nil
            }
            return BundleInfo(
                url: parentURL.appendingPathComponent(plistPath),
                bundleIdentifier: plist["CFBundleIdentifier"] as? String,
                displayName: (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String),
                executableName: plist["CFBundleExecutable"] as? String,
                shortVersion: plist["CFBundleShortVersionString"] as? String,
                buildVersion: plist["CFBundleVersion"] as? String,
                minimumOSVersion: (plist["MinimumOSVersion"] as? String) ?? (plist["LSMinimumSystemVersion"] as? String),
                platforms: plist["CFBundleSupportedPlatforms"] as? [String] ?? [],
                extensionPointIdentifier: (plist["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String,
                extensionPrincipalClass: (plist["NSExtension"] as? [String: Any])?["NSExtensionPrincipalClass"] as? String
            )
        }
    }
}
