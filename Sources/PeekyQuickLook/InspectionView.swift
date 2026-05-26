import SwiftUI
import PeekyCore

/// Quick Look 미리보기 본문.
/// 디자인: macOS 26 Liquid Glass 카드 + SF Symbol 섹션 아이콘 + 만료일 traffic-light 색상.
struct InspectionView: View {
    let inspection: Inspection

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let archive = inspection.archive {
                        Card(title: "Archive", icon: "archivebox.fill", tint: .purple) {
                            archiveBody(archive)
                        }
                    }
                    if let bundle = inspection.bundle {
                        Card(title: bundleCardTitle, icon: bundleCardIcon, tint: .blue) {
                            bundleBody(bundle)
                        }
                    }
                    if let signing = inspection.signing {
                        Card(
                            title: signing.isAdHoc ? "Code Signing (ad-hoc)" : "Code Signing",
                            icon: "lock.shield.fill",
                            tint: signing.isAdHoc ? .orange : .green
                        ) {
                            signingBody(signing)
                        }
                    }
                    if let profile = inspection.profile {
                        Card(title: "Provisioning Profile", icon: "doc.badge.gearshape.fill", tint: .indigo) {
                            profileBody(profile)
                        }
                    }
                    if let entitlements = inspection.entitlements {
                        Card(title: "Entitlements (\(entitlements.raw.count))", icon: "checklist", tint: .teal) {
                            entitlementsBody(entitlements)
                        }
                    }
                    if !inspection.plugins.isEmpty {
                        Card(title: "Embedded Extensions (\(inspection.plugins.count))", icon: "puzzlepiece.extension.fill", tint: .pink) {
                            pluginsBody(inspection.plugins)
                        }
                    }
                    if !inspection.warnings.isEmpty {
                        Card(title: "Notes", icon: "info.circle.fill", tint: .gray) {
                            warningsBody
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Color(red: 0.30, green: 0.78, blue: 0.92), Color(red: 0.36, green: 0.42, blue: 0.93)], startPoint: .top, endPoint: .bottom))
                Image(systemName: sourceSymbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(sourceURL.lastPathComponent)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(sourceLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
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

    private func bundleBody(_ bundle: BundleInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Identifier", bundle.bundleIdentifier, mono: true)
            row("Display Name", bundle.displayName)
            row("Executable", bundle.executableName, mono: true)
            row("Version", bundle.shortVersion.map { "\($0) (\(bundle.buildVersion ?? "?"))" })
            row("Min OS", bundle.minimumOSVersion)
            if !bundle.platforms.isEmpty {
                row("Platforms", bundle.platforms.joined(separator: ", "))
            }
            if let ep = bundle.extensionPointIdentifier {
                row("Extension Point", ExtensionKind.humanize(ep))
            }
            if let pc = bundle.extensionPrincipalClass {
                row("Principal Class", pc, mono: true)
            }
        }
    }

    // MARK: - Signing

    private func signingBody(_ signing: SigningInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Identifier", signing.identifier, mono: true)
            row("Team ID", signing.teamIdentifier, mono: true)
            row("Signing Identity", signing.signingIdentity)
            if !signing.certificateChain.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Certificate Chain")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(Array(signing.certificateChain.enumerated()), id: \.offset) { idx, cert in
                    certificateRow(idx: idx, cert: cert)
                }
            }
        }
    }

    private func certificateRow(idx: Int, cert: SigningInfo.Certificate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(idx)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(cert.commonName)
                    .font(.callout)
                    .textSelection(.enabled)
                if let org = cert.organization {
                    Text(org)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notAfter = cert.notAfter {
                    expirationLabel(prefix: "Expires", date: notAfter, font: .caption2)
                }
            }
        }
        .padding(.leading, 4)
    }

    // MARK: - Profile

    private func profileBody(_ profile: ProvisioningProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Name", profile.name)
            row("UUID", profile.uuid, mono: true)
            row("AppID Name", profile.appIDName)
            row("Team", teamLabel(profile))
            row("Created", profile.creationDate.map { Self.dateFormatter.string(from: $0) })
            if let expires = profile.expirationDate {
                HStack(alignment: .firstTextBaseline) {
                    Text("Expires")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    expirationLabel(prefix: "", date: expires, font: .callout)
                    Spacer()
                }
            }
            row("Devices", profile.devicesCount.map { "\($0) devices" } ?? (profile.provisionsAllDevices ? "All devices" : nil))
            if !profile.platform.isEmpty {
                row("Platform", profile.platform.joined(separator: ", "))
            }
        }
    }

    private func teamLabel(_ profile: ProvisioningProfile) -> String? {
        guard let name = profile.teamName else { return profile.teamIdentifier.joined(separator: ", ").nilIfEmpty }
        if profile.teamIdentifier.isEmpty { return name }
        return "\(name) (\(profile.teamIdentifier.joined(separator: ", ")))"
    }

    // MARK: - Entitlements

    private func entitlementsBody(_ entitlements: Entitlements) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entitlements.raw.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 2) {
                    Text(key)
                        .font(.caption.monospaced().weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(entitlementValueDescription(entitlements.raw[key]))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Plugins

    private func pluginsBody(_ plugins: [BundleInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(plugins, id: \.url) { plugin in
                pluginRow(plugin)
            }
        }
    }

    private func pluginRow(_ plugin: BundleInfo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ExtensionKind.symbol(for: plugin.extensionPointIdentifier))
                .font(.callout)
                .foregroundStyle(.pink)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayPluginName(plugin))
                        .font(.callout.weight(.medium))
                    if let kind = plugin.extensionPointIdentifier {
                        Text(ExtensionKind.humanize(kind))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.pink.opacity(0.15), in: Capsule())
                    }
                }
                Text(plugin.bundleIdentifier ?? "—")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
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

    private func archiveBody(_ archive: ArchiveInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Scheme", archive.schemeName ?? archive.name)
            row("Created", archive.creationDate.map { Self.dateFormatter.string(from: $0) })
            row("Archive v.", archive.archiveVersion.map(String.init))
            row("Signing Identity", archive.signingIdentity)
            row("Team", archive.teamIdentifier, mono: true)
            row("App Path", archive.applicationPath, mono: true)
            HStack(alignment: .firstTextBaseline) {
                Text("dSYMs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)
                Text("\(archive.dSYMCount)개")
                    .font(.callout)
                if archive.dSYMCount > 0 {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Spacer()
            }
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

    // MARK: - Row helper

    private func row(_ label: String, _ value: String?, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value?.isEmpty == false ? value! : "—")
                .font(mono ? .callout.monospaced() : .callout)
                .textSelection(.enabled)
                .lineLimit(2)
            Spacer()
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

// MARK: - Card with Liquid Glass

private struct Card<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
