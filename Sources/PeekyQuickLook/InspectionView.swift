import SwiftUI
import PeekyCore

/// Quick Look 미리보기 본문. Phase 6에서 카드별 컴포넌트로 분리.
struct InspectionView: View {
    let inspection: Inspection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                title
                if let bundle = inspection.bundle {
                    bundleCard(bundle)
                }
                if let profile = inspection.profile {
                    profileCard(profile)
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
