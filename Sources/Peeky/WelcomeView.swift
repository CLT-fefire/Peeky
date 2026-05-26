import SwiftUI

/// 호스트 앱 메인 화면 — Quick Look 익스텐션 활성화 가이드.
struct WelcomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                stepsCard
                quarantineCard
            }
            .padding(32)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Peeky")
                .font(.system(size: 36, weight: .bold))
            Text("스페이스바 한 번으로 `.app` `.appex` `.ipa` `.mobileprovision` 들여다보기")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var stepsCard: some View {
        GroupBox("사용 시작") {
            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1, text: "Peeky를 `/Applications/`로 옮기세요.")
                stepRow(number: 2, text: "시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → Quick Look 에서 Peeky 활성화.")
                stepRow(number: 3, text: "Finder에서 `.ipa` 또는 `.app`을 선택하고 스페이스바를 누르세요.")
            }
            .padding(.vertical, 8)
        }
    }

    private var quarantineCard: some View {
        GroupBox("DMG로 처음 설치한 경우") {
            VStack(alignment: .leading, spacing: 8) {
                Text("서명되지 않은 빌드라 macOS가 격리(quarantine) 속성을 붙입니다. 터미널에서 한 번만:")
                    .font(.callout)
                CodeBlock(text: "xattr -dr com.apple.quarantine /Applications/Peeky.app")
            }
            .padding(.vertical, 8)
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 24, height: 24)
                .background(.tint.opacity(0.15), in: Circle())
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

private struct CodeBlock: View {
    let text: String

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
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("복사")
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
