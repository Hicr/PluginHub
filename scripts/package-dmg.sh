#!/bin/bash
# PluginHub DMG 打包脚本
#   免费 Apple ID：ad-hoc 签名，用户首次需右键 → 打开
#   付费 Developer ID：签名 + 公证，用户双击即可打开
set -e

# ── 配置 ──────────────────────────────────────────────
APP_NAME="PluginHub"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release"
STAGE_DIR=".build/dmg-stage"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ENTITLEMENTS="scripts/PluginHub.entitlements"

# 签名（通过环境变量配置，不设置则 ad-hoc 签名）
IDENTITY="${PLUGINHUB_SIGN_IDENTITY:--}"
TEAM_ID="${PLUGINHUB_TEAM_ID:-}"
# 公证用（付费账号需要）
APPLE_ID="${PLUGINHUB_APPLE_ID:-}"
APP_PASSWORD="${PLUGINHUB_APP_PASSWORD:-}"

echo "==> 1. 清理旧产物"
rm -rf "$STAGE_DIR" "$BUILD_DIR/${APP_NAME}.app"

echo "==> 2. Release 构建"
swift build -c release --product "$APP_NAME"
swift build -c release --product "${APP_NAME}Widget" 2>/dev/null || echo "     (Widget 跳过)"

echo "==> 3. 组装 .app bundle"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/${APP_NAME}" "$APP_DIR/Contents/MacOS/"
cp "Resources/PluginHub.icns" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp "Resources/menubar-icon.png" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp "Resources/PluginAuthoringGuide.html" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp -r "Resources/BundledPlugins" "$APP_DIR/Contents/Resources/Plugins" 2>/dev/null || true

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PluginHub</string>
    <key>CFBundleIdentifier</key>
    <string>com.pluginhub.app</string>
    <key>CFBundleName</key>
    <string>PluginHub</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>PluginHub</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Widget .appex
WIDGET_BIN="$BUILD_DIR/${APP_NAME}Widget"
if [ -f "$WIDGET_BIN" ]; then
    WIDGET_DIR="$APP_DIR/Contents/PlugIns/${APP_NAME}Widget.appex"
    mkdir -p "$WIDGET_DIR/Contents/MacOS"
    cp "$WIDGET_BIN" "$WIDGET_DIR/Contents/MacOS/${APP_NAME}Widget"

    cat > "$WIDGET_DIR/Contents/Info.plist" << 'WPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PluginHubWidget</string>
    <key>CFBundleIdentifier</key>
    <string>com.pluginhub.app.widget</string>
    <key>CFBundleName</key>
    <string>PluginHubWidget</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleSupportedPlatforms</key>
    <array><string>MacOSX</string></array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>WKAppBundleIdentifier</key>
    <string>com.pluginhub.app</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
        <key>NSExtensionPrincipalClass</key>
        <string>PluginHubWidget.PluginHubWidgetBundle</string>
    </dict>
</dict>
</plist>
WPLIST
    echo "     Widget 已打包"
fi

echo "==> 4. 签名"
if [ -f "$ENTITLEMENTS" ]; then
    cp "$ENTITLEMENTS" "$APP_DIR/Contents/Resources/"
    # 先签 Widget
    if [ -d "$APP_DIR/Contents/PlugIns/${APP_NAME}Widget.appex" ]; then
        codesign --force --sign "$IDENTITY" \
            --entitlements "$ENTITLEMENTS" \
            --timestamp=none \
            "$APP_DIR/Contents/PlugIns/${APP_NAME}Widget.appex"
        echo "     Widget 已签名"
    fi
    # 签主 App
    codesign --force --deep --sign "$IDENTITY" \
        --entitlements "$ENTITLEMENTS" \
        --timestamp=none \
        "$APP_DIR"
    echo "     主 App 已签名"
else
    codesign --force --deep --sign "$IDENTITY" "$APP_DIR"
    echo "     已 ad-hoc 签名"
fi

echo "==> 5. 创建 DMG"
mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/"

# 创建 Applications 快捷方式
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

echo "     DMG: $DMG_NAME"

# ── 6. 公证（仅付费 Developer ID 签名时可用）────
if [ -n "$APPLE_ID" ] && [ -n "$APP_PASSWORD" ] && [ "$IDENTITY" != "-" ]; then
    echo "==> 6. 提交公证"
    xcrun notarytool submit "$DMG_NAME" \
        --apple-id "$APPLE_ID" \
        --password "$APP_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    echo "==> 7. 装订公证票据"
    xcrun stapler staple "$DMG_NAME"
    echo "     已公证"
else
    if [ "$IDENTITY" = "-" ]; then
        echo "==> 6. 跳过公证（ad-hoc 签名不支持公证，用户首次需右键 → 打开）"
    else
        echo "==> 6. 跳过公证（未设置 PLUGINHUB_APPLE_ID / PLUGINHUB_APP_PASSWORD）"
    fi
fi

echo ""
echo "✅ 打包完成: $DMG_NAME"
echo "   大小: $(du -h "$DMG_NAME" | cut -f1)"
