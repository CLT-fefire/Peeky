#!/bin/bash
# Peeky를 .app 번들 + Quick Look 익스텐션(.appex)으로 패키징.
# 사용: ./scripts/make_app.sh
# 결과물: ./Peeky.app

set -euo pipefail

cd "$(dirname "$0")/.."

HOST_PRODUCT="Peeky"
QL_PRODUCT="PeekyQuickLook"
APP="$HOST_PRODUCT.app"
APPEX="$QL_PRODUCT.appex"

echo "▶ Building release binaries…"
swift build -c release --product "$HOST_PRODUCT"
swift build -c release --product "$QL_PRODUCT"

BIN_DIR=".build/release"

# ---- 1. 호스트 .app 골격 ----
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mkdir -p "$APP/Contents/PlugIns"

cp "$BIN_DIR/$HOST_PRODUCT" "$APP/Contents/MacOS/$HOST_PRODUCT"
cp "Resources/HostInfo.plist" "$APP/Contents/Info.plist"

# 아이콘 (있으면 복사, 없으면 추후 생성)
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# ---- 2. Quick Look .appex 골격 ----
APPEX_DIR="$APP/Contents/PlugIns/$APPEX"
mkdir -p "$APPEX_DIR/Contents/MacOS"
mkdir -p "$APPEX_DIR/Contents/Resources"

cp "$BIN_DIR/$QL_PRODUCT" "$APPEX_DIR/Contents/MacOS/$QL_PRODUCT"
cp "Resources/QuickLookInfo.plist" "$APPEX_DIR/Contents/Info.plist"

# ---- 3. 서명 ----
# 정책: Apple Development 인증서가 있으면 그걸로 안정 서명.
# 없으면 ad-hoc (배포 시 사용자가 quarantine 속성을 직접 제거).
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Apple Development:" \
    | head -1 \
    | awk -F'"' '{print $2}' || true)

if [ -n "$IDENTITY" ]; then
    echo "▶ Signing with: $IDENTITY"
    codesign --force --sign "$IDENTITY" --options runtime "$APPEX_DIR"
    codesign --force --sign "$IDENTITY" --options runtime --deep "$APP"
else
    echo "▶ Apple Development 인증서 없음 → ad-hoc 서명 (배포 시 xattr 제거 필요)"
    codesign --force --sign - "$APPEX_DIR"
    codesign --force --sign - --deep "$APP"
fi

echo "✅ Built: $(pwd)/$APP"
echo ""
echo "실행:        open $(pwd)/$APP"
echo "설치:        mv $APP /Applications/"
echo "익스텐션 활성화: 시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → Quick Look → Peeky 켜기"
