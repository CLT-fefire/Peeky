import SwiftUI
import PeekyCore

/// Quick Look 미리보기 본문.
///
/// 디자인: macOS 26 Liquid Glass 카드 + 4-tier 시멘틱 컬러
/// (`.primary` 정보 / `.secure` 안전 / `.warning` 주의 / `.neutral` 보조).
/// Xcode/Console.app 같은 native dev tool 미감을 따라 컬러 노이즈를 절제.
struct InspectionView: View {
    let inspection: Inspection

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    if let archive = inspection.archive {
                        Card(title: "Archive", icon: "archivebox.fill", accent: .primary) {
                            archiveBody(archive)
                        }
                    }
                    if let bundle = inspection.bundle {
                        Card(title: bundleCardTitle, icon: bundleCardIcon, accent: .primary) {
                            bundleBody(bundle)
                        }
                    }
                    if let signing = inspection.signing {
                        Card(
                            title: signing.isAdHoc ? "Code Signing (ad-hoc)" : "Code Signing",
                            icon: "lock.shield.fill",
                            accent: signing.isAdHoc ? .warning : .secure
                        ) {
                            signingBody(signing)
                        }
                    }
                    if let profile = inspection.profile {
                        Card(title: "Provisioning Profile", icon: "doc.badge.gearshape.fill", accent: .primary) {
                            profileBody(profile)
                        }
                    }
                    if let entitlements = inspection.entitlements {
                        Card(title: "Entitlements (\(entitlements.raw.count))", icon: "checklist", accent: .neutral) {
                            entitlementsBody(entitlements)
                        }
                    }
                    if !inspection.plugins.isEmpty {
                        Card(title: "Embedded Extensions (\(inspection.plugins.count))", icon: "puzzlepiece.extension.fill", accent: .primary) {
                            pluginsBody(inspection.plugins)
                        }
                    }
                    if !inspection.warnings.isEmpty {
                        Card(title: "Notes", icon: "info.circle.fill", accent: .neutral) {
                            warningsBody
                        }
                    }
                }
                .padding(18)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.30, green: 0.78, blue: 0.92),
                            Color(red: 0.36, green: 0.42, blue: 0.93),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                Image(systemName: sourceSymbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 1) {
                Text(sourceURL.lastPathComponent)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(sourceLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Bundle

    private var bundleCardTitle: String {
        switch inspection.source {
        case .appex: return "App Extension"
        case .ipa: return "iOS App"
        default: return "Bundle"
        }
    }

    private var bundleCardIcon: String {
        switch inspection.source {
        case .appex: return "puzzlepiece.extension.fill"
        case .ipa: return "iphone"
        case .app: return "app.fill"
        default: return "app.fill"
        }
    }

    @ViewBuilder
    private func bundleBody(_ bundle: BundleInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Identifier", bundle.bundleIdentifier, mono: true)
            row("Display Name", bundle.displayName)
            row("Executable", bundle.executableName, mono: true)
            row("Version", bundle.shortVersion.map { "\($0) (\(bundle.buildVersion ?? "?"))" })
            row("Min OS", bundle.minimumOSVersion)
            row("Platforms", bundle.platforms.isEmpty ? nil : bundle.platforms.joined(separator: ", "))
            row("Extension Point", bundle.extensionPointIdentifier.map(ExtensionKind.humanize))
            row("Principal Class", bundle.extensionPrincipalClass, mono: true)
        }
    }

    // MARK: - Signing

    @ViewBuilder
    private func signingBody(_ signing: SigningInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Identifier", signing.identifier, mono: true)
            row("Team ID", signing.teamIdentifier, mono: true)
            row("Signing Identity", signing.signingIdentity)
            if !signing.certificateChain.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                Text("Certificate Chain")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
                ForEach(Array(signing.certificateChain.enumerated()), id: \.offset) { idx, cert in
                    certificateRow(idx: idx, cert: cert, isLast: idx == signing.certificateChain.count - 1)
                }
            }
        }
    }

    private func certificateRow(idx: Int, cert: SigningInfo.Certificate, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 체인 흐름 시각화 — 왼쪽 세로선 + 노드
            VStack(spacing: 0) {
                Circle()
                    .fill(idx == 0 ? Color.accentColor : Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 6)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(cert.commonName)
                    .font(.callout)
                if let org = cert.organization {
                    Text(org)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notAfter = cert.notAfter {
                    expirationLabel(prefix: "Expires", date: notAfter, font: .caption2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Profile

    @ViewBuilder
    private func profileBody(_ profile: ProvisioningProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Name", profile.name)
            row("UUID", profile.uuid, mono: true)
            row("AppID Name", profile.appIDName)
            row("Team", teamLabel(profile))
            row("Created", profile.creationDate.map { Self.dateFormatter.string(from: $0) })
            if let expires = profile.expirationDate {
                expirationRow(label: "Expires", date: expires)
            }
            row("Devices", profile.devicesCount.map { "\($0) devices" } ?? (profile.provisionsAllDevices ? "All devices" : nil))
            row("Platform", profile.platform.isEmpty ? nil : profile.platform.joined(separator: ", "))
        }
    }

    private func teamLabel(_ profile: ProvisioningProfile) -> String? {
        guard let name = profile.teamName else { return profile.teamIdentifier.joined(separator: ", ").nilIfEmpty }
        if profile.teamIdentifier.isEmpty { return name }
        return "\(name) (\(profile.teamIdentifier.joined(separator: ", ")))"
    }

    // MARK: - Entitlements

    private func entitlementsBody(_ entitlements: Entitlements) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entitlements.raw.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 1) {
                    Text(key)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(entitlementValueDescription(entitlements.raw[key]))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
    }

    // MARK: - Plugins

    private func pluginsBody(_ plugins: [BundleInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(plugins, id: \.url) { plugin in
                pluginRow(plugin)
            }
        }
    }

    private func pluginRow(_ plugin: BundleInfo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ExtensionKind.symbol(for: plugin.extensionPointIdentifier))
                .font(.callout)
                .foregroundStyle(.tint)
                .frame(width: 20, alignment: .center)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayPluginName(plugin))
                        .font(.callout.weight(.medium))
                    if let kind = plugin.extensionPointIdentifier {
                        Text(ExtensionKind.humanize(kind))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.secondary.opacity(0.12))
                            )
                    }
                }
                if let bid = plugin.bundleIdentifier {
                    Text(bid)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func displayPluginName(_ plugin: BundleInfo) -> String {
        // .ipa의 PlugIn URL은 zip 내부 가상 경로(`...appex/Info.plist`)라 한 단계 위로
        let last = plugin.url.lastPathComponent
        if last == "Info.plist" {
            return plugin.url.deletingLastPathComponent().deletingPathExtension().lastPathComponent
        }
        return plugin.url.deletingPathExtension().lastPathComponent
    }

    // MARK: - Archive

    @ViewBuilder
    private func archiveBody(_ archive: ArchiveInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Scheme", archive.schemeName ?? archive.name)
            row("Created", archive.creationDate.map { Self.dateFormatter.string(from: $0) })
            row("Archive v.", archive.archiveVersion.map(String.init))
            row("Signing Identity", archive.signingIdentity)
            row("Team", archive.teamIdentifier, mono: true)
            row("App Path", archive.applicationPath, mono: true)
            statusRow(
                label: "dSYMs",
                value: "\(archive.dSYMCount)개",
                ok: archive.dSYMCount > 0
            )
        }
    }

    // MARK: - Warnings

    private var warningsBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(inspection.warnings, id: \.self) { warning in
                Text(warning)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Source helpers

    private var sourceURL: URL {
        switch inspection.source {
        case .app(let u), .appex(let u), .ipa(let u), .xcarchive(let u), .profile(let u): return u
        }
    }

    private var sourceLabel: String {
        switch inspection.source {
        case .app: return "macOS / iOS Application Bundle"
        case .appex: return "App Extension"
        case .ipa: return "iOS App Archive (.ipa)"
        case .xcarchive: return "Xcode Archive"
        case .profile: return "Provisioning Profile"
        }
    }

    private var sourceSymbol: String {
        switch inspection.source {
        case .app: return "app.fill"
        case .appex: return "puzzlepiece.extension.fill"
        case .ipa: return "iphone"
        case .xcarchive: return "archivebox.fill"
        case .profile: return "doc.badge.gearshape.fill"
        }
    }

    // MARK: - Row helpers

    /// 표준 한 줄 항목. value가 nil/빈 문자열이면 row를 그리지 않는다 — "—"로 공간 낭비 방지.
    @ViewBuilder
    private func row(_ label: String, _ value: String?, mono: Bool = false) -> some View {
        if let v = value, !v.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)
                Text(v)
                    .font(mono ? .system(.callout, design: .monospaced) : .callout)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
    }

    /// 만료일 row — traffic-light 색상 + 잔여 일수.
    private func expirationRow(label: String, date: Date) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            expirationLabel(prefix: "", date: date, font: .callout)
            Spacer(minLength: 0)
        }
    }

    /// 상태 row — value 옆에 ✓/⚠ 아이콘. dSYM 등 yes/no 상태 표시용.
    private func statusRow(label: String, value: String, ok: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.callout)
            Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .orange)
                .font(.caption)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Expiration coloring

    private func expirationLabel(prefix: String, date: Date, font: Font) -> some View {
        let now = Date()
        let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
        let (color, suffix): (Color, String) = {
            if date < now { return (.red, " (만료됨)") }
            if days < 7 { return (.red, " (\(days)일 남음)") }
            if days < 30 { return (.orange, " (\(days)일 남음)") }
            if days < 90 { return (.blue, " (\(days)일 남음)") }
            return (.secondary, "")
        }()
        let dateStr = Self.dateFormatter.string(from: date)
        let display = prefix.isEmpty ? "\(dateStr)\(suffix)" : "\(prefix) \(dateStr)\(suffix)"
        return Text(display)
            .font(font)
            .foregroundStyle(color)
    }

    // MARK: - Helpers

    private func entitlementValueDescription(_ value: Any?) -> String {
        switch value {
        case let s as String: return "\"\(s)\""
        case let b as Bool: return b ? "true" : "false"
        case let arr as [Any]: return arr.map { "\($0)" }.joined(separator: "\n")
        case let dict as [String: Any]: return "{\(dict.count) keys}"
        case let n as NSNumber: return "\(n)"
        case nil: return "—"
        default: return String(describing: value!)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

// MARK: - 4-tier semantic accent system

/// 카드의 시멘틱 등급. native dev tool 미감을 위해 컬러 노이즈를 4단계로 절제.
enum CardAccent {
    /// 정보 카드 (Bundle, Profile, Archive, Extensions). 시스템 강조색.
    case primary
    /// 안전·검증 완료 (정상 코드 서명). green.
    case secure
    /// 주의·경고 (ad-hoc 서명, 만료 임박). orange.
    case warning
    /// 보조 정보 (Entitlements raw 데이터, Notes). secondary.
    case neutral

    var color: Color {
        switch self {
        case .primary: return .accentColor
        case .secure: return .green
        case .warning: return .orange
        case .neutral: return .secondary
        }
    }
}

// MARK: - Card with Liquid Glass

private struct Card<Content: View>: View {
    let title: String
    let icon: String
    let accent: CardAccent
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(accent.color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Extension kind humanization

private enum ExtensionKind {
    static func humanize(_ identifier: String) -> String {
        switch identifier {
        case "com.apple.share-services": return "Share"
        case "com.apple.widget-extension": return "Today Widget"
        case "com.apple.widgetkit-extension": return "WidgetKit"
        case "com.apple.usernotifications.service": return "Notification Service"
        case "com.apple.usernotifications.content-extension": return "Notification Content"
        case "com.apple.intents-service": return "Intents"
        case "com.apple.intents-ui-service": return "Intents UI"
        case "com.apple.keyboard-service": return "Keyboard"
        case "com.apple.spotlight.import": return "Spotlight Import"
        case "com.apple.spotlight.index": return "Spotlight Index"
        case "com.apple.quicklook.preview": return "Quick Look"
        case "com.apple.quicklook.thumbnail": return "QL Thumbnail"
        case "com.apple.fileprovider-nonui": return "File Provider"
        case "com.apple.fileprovider-actionsui": return "File Provider UI"
        case "com.apple.networkextension.packet-tunnel": return "Network Extension"
        case "com.apple.broadcast-services-upload": return "Broadcast Upload"
        case "com.apple.message-payload-provider": return "Message Payload"
        case "com.apple.callkit.call-directory": return "Call Directory"
        case "com.apple.authentication-services-credential-provider-ui": return "Credential Provider"
        default:
            return identifier.components(separatedBy: ".").last ?? identifier
        }
    }

    static func symbol(for identifier: String?) -> String {
        switch identifier {
        case "com.apple.share-services": return "square.and.arrow.up"
        case "com.apple.widget-extension", "com.apple.widgetkit-extension": return "square.grid.2x2.fill"
        case "com.apple.usernotifications.service", "com.apple.usernotifications.content-extension": return "bell.badge.fill"
        case "com.apple.intents-service", "com.apple.intents-ui-service": return "waveform.circle.fill"
        case "com.apple.keyboard-service": return "keyboard.fill"
        case "com.apple.spotlight.import", "com.apple.spotlight.index": return "magnifyingglass.circle.fill"
        case "com.apple.quicklook.preview", "com.apple.quicklook.thumbnail": return "eye.fill"
        case "com.apple.fileprovider-nonui", "com.apple.fileprovider-actionsui": return "folder.fill.badge.gearshape"
        case "com.apple.networkextension.packet-tunnel": return "network"
        case "com.apple.callkit.call-directory": return "phone.fill"
        default: return "puzzlepiece.extension.fill"
        }
    }
}

// MARK: - Small utilities

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
