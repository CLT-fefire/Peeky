import SwiftUI
import AppKit

/// 호스트 앱 메인 화면 — Quick Look 익스텐션 활성화 가이드 + 빠른 액션.
///
/// 디자인: macOS 26 Liquid Glass + 4-tier 시멘틱 컬러 (InspectionView와 일관).
/// 마스코트 hero + step 가이드 + 지원 파일 + 격리 해제 안내 + GitHub 액션.
struct WelcomeView: View {
    var body: some View {
        GlassEffectContainer(spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    actionsRow
                    stepsCard
                    supportedTypesCard
                    quarantineCard
                    footer
                }
                .padding(28)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 20) {
            mascot
            VStack(alignment: .leading, spacing: 4) {
                Text("Peeky")
                    .font(.system(size: 40, weight: .bold))
                Text("스페이스바 한 번으로 `.app` `.appex` `.ipa` `.mobileprovision` 들여다보기")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    /// 호스트 앱 자체의 AppIcon을 큰 사이즈로 보여준다.
    private var mascot: some View {
        Image(nsImage: NSApp.applicationIconImage ?? NSImage())
            .resizable()
            .frame(width: 88, height: 88)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: 10) {
            Button {
                openExtensionsSettings()
            } label: {
                Label("Quick Look 익스텐션 설정 열기", systemImage: "gearshape.fill")
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)

            Button {
                openGitHub()
            } label: {
                Label("GitHub", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Steps

    private var stepsCard: some View {
        Card(title: "사용 시작", icon: "list.number", accent: .primary) {
            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: 1, text: "이 앱을 `/Applications/`로 옮기세요.")
                stepRow(number: 2, text: "위의 **Quick Look 익스텐션 설정 열기** 버튼을 눌러 시스템 설정에서 Peeky를 켜세요.")
                stepRow(number: 3, text: "Finder에서 `.ipa` `.app` `.appex` `.mobileprovision` 파일을 선택하고 스페이스바.")
            }
        }
    }

    // MARK: - Supported types

    private var supportedTypesCard: some View {
        Card(title: "지원 파일", icon: "doc.badge.checkmark.fill", accent: .secure) {
            VStack(alignment: .leading, spacing: 8) {
                typeRow(ext: ".app", desc: "macOS / iOS 애플리케이션 번들", symbol: "app.fill")
                typeRow(ext: ".appex", desc: "App Extension (Share / Widget / NSE 등)", symbol: "puzzlepiece.extension.fill")
                typeRow(ext: ".ipa", desc: "iOS 앱 아카이브 (디스크 추출 없이 검사)", symbol: "iphone")
                typeRow(ext: ".xcarchive", desc: "Xcode 아카이브 (dSYM 유무 포함)", symbol: "archivebox.fill")
                typeRow(ext: ".mobileprovision / .provisionprofile", desc: "프로비저닝 프로파일", symbol: "doc.badge.gearshape.fill")
            }
        }
    }

    private func typeRow(ext: String, desc: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text(ext)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .frame(width: 224, alignment: .leading)
            Text(desc)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Quarantine

    private var quarantineCard: some View {
        Card(title: "DMG로 처음 설치한 경우", icon: "shield.lefthalf.filled", accent: .warning) {
            VStack(alignment: .leading, spacing: 8) {
                Text("서명되지 않은 빌드라 macOS가 격리(quarantine) 속성을 붙입니다. 터미널에서 한 번만 실행:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                CodeBlock(text: "xattr -dr com.apple.quarantine /Applications/Peeky.app")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Text("Peeky 0.1.0")
            Text("·")
            Text("MIT License")
            Spacer()
            Text("스페이스바를 누르세요 →")
                .italic()
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.top, 8)
    }

    // MARK: - Step row

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .frame(width: 24, height: 24)
                .foregroundStyle(.white)
                .background(.tint, in: Circle())
            Text(.init(text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: - Actions

    /// 시스템 설정 → 로그인 항목 및 확장 프로그램 패널 열기.
    private func openExtensionsSettings() {
        // macOS 13+ System Settings 딥링크. Quick Look 직접 진입 URL은 안정성이 낮아
        // Login Items & Extensions 패널까지만 열고 사용자가 Quick Look 섹션을 클릭하도록 안내.
        let candidates = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences?QuickLook",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.extensions",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func openGitHub() {
        if let url = URL(string: "https://github.com/CLT-fefire/Peeky") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 4-tier semantic accent (InspectionView와 일관)

private enum CardAccent {
    case primary, secure, warning, neutral
    var color: Color {
        switch self {
        case .primary: return .accentColor
        case .secure: return .green
        case .warning: return .orange
        case .neutral: return .secondary
        }
    }
}

// MARK: - Card (Liquid Glass)

private struct Card<Content: View>: View {
    let title: String
    let icon: String
    let accent: CardAccent
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(accent.color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

private struct CodeBlock: View {
    let text: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
                withAnimation(.easeOut(duration: 0.18)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeIn(duration: 0.18)) { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .help("복사")
        }
        .padding(12)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
