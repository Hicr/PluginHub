#!/bin/bash
# 快速创建开发版 .app bundle，用于测试通知等功能
set -e

BUILD_DIR=".build/arm64-apple-macosx/debug"
APP_DIR="$BUILD_DIR/PluginHub.app"

swift build

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/PluginHub" "$APP_DIR/Contents/MacOS/"
cp "Resources/PluginAuthoringGuide.html" "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp -r "Resources/BundledPlugins" "$APP_DIR/Contents/Resources/Plugins" 2>/dev/null || true

# 创建 Info.plist
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
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# 杀掉旧进程
killall PluginHub 2>/dev/null || true

echo "✅ 开发版 App 已创建: $APP_DIR"
echo "运行: open $APP_DIR"
