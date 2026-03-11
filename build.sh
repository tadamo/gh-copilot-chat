#!/bin/bash
set -e

APP_NAME="GH Copilot Chat"
APP_DIR="${APP_NAME}.app"

echo "🔨 Building ${APP_NAME}..."

swiftc GHCopilotChat.swift \
    -framework AppKit \
    -framework WebKit \
    -o GHCopilotChat_bin

echo "📦 Creating .app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
mv GHCopilotChat_bin "${APP_DIR}/Contents/MacOS/GHCopilotChat"

cat > "${APP_DIR}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GHCopilotChat</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.ghcopilotchat</string>
    <key>CFBundleName</key>
    <string>GH Copilot Chat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

ICONSET="${APP_DIR}/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICONSET"

if file ./gh-copilot-chat.png | grep -q PNG; then
    echo "✅ Icon found."
    for size in 16 32 64 128 256 512 1024; do
        sips -z $size $size ./gh-copilot-chat.png \
            --out "${ICONSET}/icon_${size}x${size}.png" &> /dev/null
        if [ $size -le 512 ]; then
            double=$((size * 2))
            sips -z $double $double ./gh-copilot-chat.png \
                --out "${ICONSET}/icon_${size}x${size}@2x.png" &> /dev/null
        fi
    done
    iconutil -c icns "$ICONSET" -o "${APP_DIR}/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
    echo "✅ AppIcon.icns created."
else
    echo "⚠️  Icon file not found — place gh-copilot-chat.png in this directory."
fi

echo ""
echo "✅ '${APP_DIR}' is ready."
echo ""
echo "To install:"
echo "  cp -r '${APP_DIR}' /Applications/"
echo ""
echo "First launch: right-click → Open to bypass Gatekeeper."
echo ""
echo "To test now:"
echo "  open '${APP_DIR}'"
