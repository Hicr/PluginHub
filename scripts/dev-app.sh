#!/bin/bash
# 快速创建开发版 .app bundle，用于测试通知和 Widget 功能
set -e

BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_DIR="$BUILD_DIR/PluginHub.app"
ENTITLEMENTS="scripts/PluginHub.entitlements"

# 构建主 App 和 Widget
swift build --product PluginHub
swift build --product PluginHubWidget 2>/dev/null || echo "⚠️  Widget 构建跳过（需要 macOS 14+）"

# 清理旧 app
rm -rf "$APP_DIR"

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/PluginHub" "$APP_DIR/Contents/MacOS/"
cp "Resources/PluginAuthoringGuide.html" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp "Resources/PluginHub.icns" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp "Resources/menubar-icon.png" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp -r "Resources/BundledPlugins" "$APP_DIR/Contents/Resources/Plugins" 2>/dev/null || true

# 创建主 App Info.plist
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
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>PluginHub</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# 创建 Widget .appex bundle
WIDGET_BIN="$BUILD_DIR/PluginHubWidget"
if [ -f "$WIDGET_BIN" ]; then
    WIDGET_DIR="$APP_DIR/Contents/PlugIns/PluginHubWidget.appex"
    mkdir -p "$WIDGET_DIR/Contents/MacOS"
    cp "$WIDGET_BIN" "$WIDGET_DIR/Contents/MacOS/PluginHubWidget"

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
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
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
    echo "✅ Widget 已打包"
fi

# 复制并签名 entitlements
IDENTITY="EAD3C0F5733F71A5233B1F01AA493F967B75F87F"
TEAM_ID="XR2TL8QHWL"

if [ -f "$ENTITLEMENTS" ]; then
    cp "$ENTITLEMENTS" "$APP_DIR/Contents/Resources/"
    # 签名 Widget 和主 App
    if [ -d "$APP_DIR/Contents/PlugIns/PluginHubWidget.appex" ]; then
        codesign --force --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" --timestamp=none "$APP_DIR/Contents/PlugIns/PluginHubWidget.appex" 2>&1
        echo "Widget 签名: $?"
    fi
    codesign --force --deep --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" --timestamp=none "$APP_DIR" 2>&1
    echo "App 签名: $?"
else
    codesign --force --deep --sign - "$APP_DIR"
fi

# 杀掉旧进程
killall PluginHub 2>/dev/null || true

echo "✅ 开发版 App 已创建: $APP_DIR"
echo "运行: open $APP_DIR"
