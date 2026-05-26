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

EXT_ENTITLEMENTS="Resources/PeekyQuickLook.entitlements"

# Hardened Runtime + ad-hoc + sandbox 조합은 pkd가 거부하는 경우가 있어 ad-hoc에선 runtime 생략.
# Apple Development 인증서는 runtime 유지.
if [ -n "$IDENTITY" ]; then
    echo "▶ Signing with: $IDENTITY"
    codesign --force --sign "$IDENTITY" --options runtime \
        --entitlements "$EXT_ENTITLEMENTS" \
        "$APPEX_DIR"
    codesign --force --sign "$IDENTITY" --options runtime "$APP"
else
    echo "▶ Apple Development 인증서 없음 → ad-hoc 서명 (runtime 생략, sandbox만)"
    codesign --force --sign - --entitlements "$EXT_ENTITLEMENTS" "$APPEX_DIR"
    codesign --force --sign - "$APP"
fi

# 서명 직후 entitlement 검증 — pkd가 "must be sandboxed"로 거부 못하게 사전 확인.
echo ""
echo "▶ Entitlements verification:"
ENT_CHECK=$(codesign -d --entitlements - "$APPEX_DIR" 2>&1 | grep -c "com.apple.security.app-sandbox")
if [ "$ENT_CHECK" -ge 1 ]; then
    echo "   ✓ sandbox entitlement embedded"
else
    echo "   ✗ sandbox entitlement MISSING — 익스텐션이 pluginkit에 등록되지 않음!"
    echo "   (Resources/PeekyQuickLook.entitlements 파일 확인 필요)"
    exit 1
fi

echo "✅ Built: $(pwd)/$APP"
echo ""
echo "실행:        open $(pwd)/$APP"
echo ""
echo "설치 (반드시 ditto + 설치 위치 재서명 — cp -R은 코드 서명 메타데이터 손실 가능):"
echo "   rm -rf /Applications/$APP"
echo "   ditto $APP /Applications/$APP"
echo "   codesign --force --sign - --entitlements $EXT_ENTITLEMENTS \\"
echo "       /Applications/$APP/Contents/PlugIns/$APPEX"
echo "   codesign --force --sign - /Applications/$APP"
echo "   pluginkit -a /Applications/$APP/Contents/PlugIns/$APPEX"
echo "   qlmanage -r && killall Finder"
echo ""
echo "익스텐션 활성화: 시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → Quick Look → Peeky 켜기"
