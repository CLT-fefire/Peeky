import SwiftUI
import PeekyCore

/// Quick Look 미리보기 본문. Phase 6에서 카드별 컴포넌트로 분리.
struct InspectionView: View {
    let inspection: Inspection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title
                if let archive = inspection.archive {
                    archiveCard(archive)
                }
                if let bundle = inspection.bundle {
                    bundleCard(bundle)
                }
                if let signing = inspection.signing {
                    signingCard(signing)
                }
                if let profile = inspection.profile {
                    profileCard(profile)
                }
                if let entitlements = inspection.entitlements {
                    entitlementsCard(entitlements)
                }
                if !inspection.plugins.isEmpty {
                    pluginsCard(inspection.plugins)
                }
                if !inspection.warnings.isEmpty {
                    warningsCard
                }
            }
            .padding(20)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sourceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(sourceURL.lastPathComponent)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
        }
    }

    private var sourceURL: URL {
        switch inspection.source {
        case .app(let u), .appex(let u), .ipa(let u), .xcarchive(let u), .profile(let u): return u
        }
    }

    private var sourceLabel: String {
        switch inspection.source {
        case .app: return "macOS / iOS Application"
        case .appex: return "App Extension"
        case .ipa: return "iOS App Archive"
        case .xcarchive: return "Xcode Archive"
        case .profile: return "Provisioning Profile"
        }
    }

    private func bundleCard(_ bundle: BundleInfo) -> some View {
        GroupBox("Bundle") {
            VStack(alignment: .leading, spacing: 6) {
                row("Identifier", bundle.bundleIdentifier)
                row("Display Name", bundle.displayName)
                row("Version", bundle.shortVersion.map { "\($0) (\(bundle.buildVersion ?? "?"))" })
                row("Min OS", bundle.minimumOSVersion)
                row("Extension Point", bundle.extensionPointIdentifier)
                row("Principal Class", bundle.extensionPrincipalClass)
            }
            .padding(.vertical, 6)
        }
    }

    private func profileCard(_ profile: ProvisioningProfile) -> some View {
        GroupBox("Provisioning Profile") {
            VStack(alignment: .leading, spacing: 6) {
                row("Name", profile.name)
                row("UUID", profile.uuid)
                row("AppID Name", profile.appIDName)
                row("Team", profile.teamName)
                row("Team ID", profile.teamIdentifier.joined(separator: ", "))
                row("Expires", profile.expirationDate.map { Self.dateFormatter.string(from: $0) })
                row("Devices", profile.devicesCount.map(String.init))
            }
            .padding(.vertical, 6)
        }
    }

    private var warningsCard: some View {
        GroupBox("Notes") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(inspection.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func archiveCard(_ archive: ArchiveInfo) -> some View {
        GroupBox("Archive") {
            VStack(alignment: .leading, spacing: 6) {
                row("Scheme", archive.schemeName ?? archive.name)
                row("Created", archive.creationDate.map { Self.dateFormatter.string(from: $0) })
                row("Archive v.", archive.archiveVersion.map(String.init))
                row("Signing Identity", archive.signingIdentity)
                row("Team", archive.teamIdentifier)
                row("App Path", archive.applicationPath)
                row("dSYMs", "\(archive.dSYMCount)개")
            }
            .padding(.vertical, 6)
        }
    }

    private func signingCard(_ signing: SigningInfo) -> some View {
        GroupBox(signing.isAdHoc ? "Code Signing (ad-hoc)" : "Code Signing") {
            VStack(alignment: .leading, spacing: 6) {
                row("Identifier", signing.identifier)
                row("Team ID", signing.teamIdentifier)
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
            .padding(.vertical, 6)
        }
    }

    private func certificateRow(idx: Int, cert: SigningInfo.Certificate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(idx)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cert.commonName)
                        .font(.callout)
                    if let org = cert.organization {
                        Text(org)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let notAfter = cert.notAfter {
                        Text("Expires \(Self.dateFormatter.string(from: notAfter))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func entitlementsCard(_ entitlements: Entitlements) -> some View {
        GroupBox("Entitlements (\(entitlements.raw.count))") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entitlements.raw.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .firstTextBaseline) {
                        Text(key)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 240, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(entitlementValueDescription(entitlements.raw[key]))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(3)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func pluginsCard(_ plugins: [BundleInfo]) -> some View {
        GroupBox("Embedded Extensions (\(plugins.count))") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(plugins, id: \.url) { plugin in
                    pluginRow(plugin)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func pluginRow(_ plugin: BundleInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(plugin.url.deletingPathExtension().lastPathComponent)
                    .font(.callout.weight(.medium))
                if let kind = plugin.extensionPointIdentifier {
                    Text(humanizeExtensionPoint(kind))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
            }
            Text(plugin.bundleIdentifier ?? "—")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func humanizeExtensionPoint(_ identifier: String) -> String {
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

    private func entitlementValueDescription(_ value: Any?) -> String {
        switch value {
        case let s as String: return "\"\(s)\""
        case let b as Bool: return b ? "true" : "false"
        case let arr as [Any]: return "[\(arr.count) items]"
        case let dict as [String: Any]: return "{\(dict.count) keys}"
        case let n as NSNumber: return "\(n)"
        case nil: return "—"
        default: return String(describing: value!)
        }
    }

    private func row(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value?.isEmpty == false ? value! : "—")
                .font(.callout)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
