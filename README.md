# Peeky

> 스페이스바 한 번으로 `.app` `.appex` `.ipa` `.mobileprovision` 들여다보기

macOS Quick Look 익스텐션. Finder에서 앱/익스텐션/프로비저닝 프로파일을 선택하고 스페이스바를 누르면 번들 정보, 코드 서명, 팀 ID, entitlements, 임베디드 프로비저닝 프로파일을 한 화면에 띄워줍니다.

ProvisionQL의 정신적 후속으로, 모던 SwiftUI + Liquid Glass 기반 재작성이며 `.appex` (App Extension) 지원을 추가했습니다.

## 지원 파일

| 확장자 | 보여주는 정보 |
|---|---|
| `.app` | Bundle ID / Version / Min OS / 서명 / 팀 ID / Entitlements / 임베디드 프로파일 / 포함된 .appex 리스트 |
| `.appex` | 위 + NSExtension 타입 (Share / Widget / NSE / Siri 등) / App Groups |
| `.ipa` | iOS 앱 메타 + 내부 .app 정보 (Phase 6) |
| `.xcarchive` | 아카이브 메타 + dSYM 유무 (Phase 7) |
| `.mobileprovision`, `.provisionprofile` | UUID / Name / Team / Expiration / Devices / Entitlements |

## 요구 사항

- macOS 26.0 (Tahoe) 이상
- Xcode 26 또는 Swift 6.2 toolchain

## 설치

### 방법 A — 소스 빌드 (권장)

```bash
git clone https://github.com/your-org/Peeky.git
cd Peeky
./scripts/make_app.sh
mv Peeky.app /Applications/
```

### 방법 B — Release DMG 다운로드

[GitHub Releases](#)에서 `Peeky-x.y.z.dmg` 다운로드 후 `/Applications/`로 드래그.

서명되지 않은 빌드라 격리 속성을 한 번 제거해야 합니다:

```bash
xattr -dr com.apple.quarantine /Applications/Peeky.app
```

## Quick Look 익스텐션 활성화

설치 후 **시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → Quick Look** 에서 Peeky를 켭니다. 그 다음 Finder에서 `.ipa` 또는 `.app`을 선택하고 스페이스바를 눌러 미리보기를 확인하세요.

## 빌드 검증

```bash
swift build
swift test
```

## 프로젝트 구조

```
Peeky/
├── Package.swift             # Swift 6.2, macOS 26
├── Sources/
│   ├── Peeky/                # 호스트 macOS 앱 (가이드 UI)
│   ├── PeekyQuickLook/       # Quick Look Preview Extension
│   └── PeekyCore/            # 공통 — BundleInspector, ProfileDecoder, SignatureReader, ZIPStreamReader
├── Resources/                # Info.plist 2종 + AppIcon
├── scripts/make_app.sh       # 호스트 .app + 내부 .appex 번들링
└── Tests/PeekyCoreTests/
```

## 라이선스

MIT. [LICENSE](LICENSE) 참조.

## 영감

- [ProvisionQL](https://github.com/ealeksandrov/ProvisionQL) (qlgenerator legacy)
- [QLMobileProvision](https://github.com/jstart/QLMobileProvision)
