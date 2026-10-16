#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: package-macos.sh
# Packages Flutter macOS desktop .app bundles into directly installable .dmg files
# ==============================================================================

VERSION="${1:-${VERSION:-1.0.0}}"
VERSION="${VERSION#v}" # Strip leading 'v'

OUTPUT_DIR="${OUTPUT_DIR:-dist}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

echo "=========================================================="
echo " Packaging macOS Releases for Version: ${VERSION}"
echo " Output Directory: ${OUTPUT_DIR}"
echo "=========================================================="

APPS=(
  "iec104_server|IEC 104 Server Simulator"
  "iec104_client|IEC 104 Client Simulator"
  "iec61850_server|IEC 61850 Server Simulator"
  "iec61850_client|IEC 61850 Client Simulator"
  "modbus_slave|Modbus Slave Emulator"
  "modbus_master|Modbus Master Emulator"
)

# Attempt to install create-dmg via Homebrew if available
if ! command -v create-dmg >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing create-dmg via Homebrew..."
    brew install create-dmg || true
  fi
fi

for APP_INFO in "${APPS[@]}"; do
  IFS="|" read -r APP_ID APP_NAME <<< "$APP_INFO"

  echo "----------------------------------------------------------"
  echo ">>> Packaging macOS DMG: ${APP_NAME} (${APP_ID})"
  echo "----------------------------------------------------------"

  APP_PATH="${APP_ID}/build/macos/Build/Products/Release/${APP_ID}.app"
  if [[ ! -d "$APP_PATH" ]]; then
    echo "ERROR: App bundle not found at $APP_PATH"
    echo "Please build the macOS app first: (cd $APP_ID && flutter build macos --release)"
    exit 1
  fi

  DMG_NAME="${APP_ID}-${VERSION}-macos.dmg"
  DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
  rm -f "$DMG_PATH"

  SUCCESS=0
  if command -v create-dmg >/dev/null 2>&1; then
    echo "Building styled drag-and-drop DMG using create-dmg..."
    set +e
    create-dmg \
      --volname "${APP_NAME}" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "${APP_ID}.app" 175 190 \
      --hide-extension "${APP_ID}.app" \
      --app-drop-link 425 190 \
      --no-internet-enable \
      "${DMG_PATH}" \
      "${APP_PATH}"
    RC=$?
    set -e
    if [[ $RC -eq 0 && -f "$DMG_PATH" ]]; then
      SUCCESS=1
      echo "✓ Styled DMG created successfully."
    else
      echo "create-dmg completed with exit code $RC. Falling back to native hdiutil..."
    fi
  fi

  if [[ $SUCCESS -eq 0 ]]; then
    echo "Building standard DMG using macOS native hdiutil..."
    STAGE_DIR="$(mktemp -d)"
    cp -R "${APP_PATH}" "${STAGE_DIR}/"
    ln -s /Applications "${STAGE_DIR}/Applications"
    hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGE_DIR}" -ov -format UDZO "${DMG_PATH}"
    rm -rf "${STAGE_DIR}"
    echo "✓ Standard DMG created successfully with hdiutil."
  fi

  echo "✓ DMG created: ${DMG_PATH}"
done

echo ""
echo "=========================================================="
echo " All macOS DMG packages created successfully in ${OUTPUT_DIR}/:"
ls -lh "$OUTPUT_DIR"
echo "=========================================================="
