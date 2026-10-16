#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: package-linux.sh
# Packages Flutter Linux desktop release bundles into .deb and .tar.gz
# ==============================================================================

VERSION="${1:-${VERSION:-1.0.0}}"
VERSION="${VERSION#v}" # Strip leading 'v' if present

HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" == "x86_64" ]]; then
  DEB_ARCH="amd64"
  FLUTTER_ARCH="x64"
  ARCH_LABEL="x64"
elif [[ "$HOST_ARCH" == "aarch64" || "$HOST_ARCH" == "arm64" ]]; then
  DEB_ARCH="arm64"
  FLUTTER_ARCH="arm64"
  ARCH_LABEL="arm64"
else
  DEB_ARCH="$HOST_ARCH"
  FLUTTER_ARCH="$HOST_ARCH"
  ARCH_LABEL="$HOST_ARCH"
fi

OUTPUT_DIR="${OUTPUT_DIR:-dist}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

echo "=========================================================="
echo " Packaging Linux Releases for Version: ${VERSION} (${ARCH_LABEL})"
echo " Output directory: ${OUTPUT_DIR}"
echo "=========================================================="

APPS=(
  "iec104_server|IEC 104 Server Simulator|IEC 60870-5-104 RTU Server Simulator|iec104_server/assets/icons/iec104_slave_app_512.png"
  "iec104_client|IEC 104 Client Simulator|IEC 60870-5-104 Master Client Simulator|iec104_client/assets/icons/iec104_master_app_512.png"
  "iec61850_server|IEC 61850 Server Simulator|IEC 61850 MMS & GOOSE Server Simulator|iec61850_server/assets/icons/iec61850_server_app_512.png"
  "iec61850_client|IEC 61850 Client Simulator|IEC 61850 MMS & GOOSE Client Simulator|iec61850_client/assets/icons/iec61850_client_app_512.png"
  "modbus_slave|Modbus Slave Emulator|Modbus RTU / TCP / UDP Slave Emulator (MSE)|modbus_slave/assets/icons/modbus_slave_app_512.png"
  "modbus_master|Modbus Master Emulator|Modbus RTU / TCP / UDP Master Emulator (MME)|modbus_master/assets/icons/modbus_master_app_512.png"
)

for APP_INFO in "${APPS[@]}"; do
  IFS="|" read -r APP_ID APP_NAME APP_DESC ICON_SRC <<< "$APP_INFO"

  echo "----------------------------------------------------------"
  echo ">>> Packaging: ${APP_NAME} (${APP_ID})"
  echo "----------------------------------------------------------"

  BUNDLE_DIR="${APP_ID}/build/linux/${FLUTTER_ARCH}/release/bundle"
  if [[ ! -d "$BUNDLE_DIR" ]]; then
    echo "ERROR: Bundle directory not found at $BUNDLE_DIR"
    echo "Please build the application first: (cd $APP_ID && flutter build linux --release --no-tree-shake-icons)"
    exit 1
  fi

  # 1. Create portable .tar.gz
  TAR_NAME="${APP_ID}-${VERSION}-linux-${ARCH_LABEL}.tar.gz"
  echo "Creating portable archive: ${TAR_NAME}..."
  # Create a renamed folder inside tar for clean extraction
  TEMP_STAGE="$(mktemp -d)"
  cp -r "$BUNDLE_DIR" "${TEMP_STAGE}/${APP_ID}"
  tar -czf "${OUTPUT_DIR}/${TAR_NAME}" -C "${TEMP_STAGE}" "${APP_ID}"
  rm -rf "${TEMP_STAGE}"

  # 2. Create directly installable .deb package
  DEB_PACKAGE_NAME="${APP_ID//_/-}" # Debian packages prefer hyphens
  DEB_FILE="${APP_ID}_${VERSION}_linux_${DEB_ARCH}.deb"
  echo "Creating Debian/Ubuntu installer package: ${DEB_FILE}..."

  PKG_ROOT="$(mktemp -d)"
  mkdir -p "${PKG_ROOT}/DEBIAN"
  mkdir -p "${PKG_ROOT}/usr/bin"
  mkdir -p "${PKG_ROOT}/usr/lib/${APP_ID}"
  mkdir -p "${PKG_ROOT}/usr/share/applications"
  mkdir -p "${PKG_ROOT}/usr/share/icons/hicolor/512x512/apps"

  # Copy bundle files into /usr/lib/<app_id>
  cp -r "${BUNDLE_DIR}/." "${PKG_ROOT}/usr/lib/${APP_ID}/"

  # Executable permissions
  chmod 755 "${PKG_ROOT}/usr/lib/${APP_ID}/${APP_ID}"

  # Create symlink in /usr/bin
  ln -sf "/usr/lib/${APP_ID}/${APP_ID}" "${PKG_ROOT}/usr/bin/${APP_ID}"
  if [[ "$APP_ID" != "$DEB_PACKAGE_NAME" ]]; then
    ln -sf "/usr/lib/${APP_ID}/${APP_ID}" "${PKG_ROOT}/usr/bin/${DEB_PACKAGE_NAME}"
  fi

  # Copy application icon
  if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "${PKG_ROOT}/usr/share/icons/hicolor/512x512/apps/${APP_ID}.png"
  fi

  # Create .desktop file
  cat << EOF > "${PKG_ROOT}/usr/share/applications/${APP_ID}.desktop"
[Desktop Entry]
Name=${APP_NAME}
Comment=${APP_DESC}
Exec=/usr/bin/${APP_ID} %u
Icon=${APP_ID}
Terminal=false
Type=Application
Categories=Development;Engineering;Utility;
Keywords=IEC104;IEC61850;Modbus;Simulator;Industrial;
StartupWMClass=${APP_ID}
EOF
  chmod 644 "${PKG_ROOT}/usr/share/applications/${APP_ID}.desktop"

  # Create DEBIAN/control file
  INSTALLED_SIZE=$(du -sk "${PKG_ROOT}/usr" | cut -f1)
  cat << EOF > "${PKG_ROOT}/DEBIAN/control"
Package: ${DEB_PACKAGE_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${DEB_ARCH}
Installed-Size: ${INSTALLED_SIZE}
Maintainer: Industrial Protocol Simulation Suite <https://github.com>
Depends: libgtk-3-0, libblkid1, liblzma5
Description: ${APP_NAME}
 ${APP_DESC}.
 High-performance cross-platform industrial protocol simulation engine built with Flutter and Dart.
EOF

  # Build the .deb
  dpkg-deb --build --root-owner-group "${PKG_ROOT}" "${OUTPUT_DIR}/${DEB_FILE}"
  rm -rf "${PKG_ROOT}"

  echo "✓ Successfully created:"
  echo "  - ${OUTPUT_DIR}/${DEB_FILE}"
  echo "  - ${OUTPUT_DIR}/${TAR_NAME}"
done

echo ""
echo "=========================================================="
echo " All Linux packages generated successfully in ${OUTPUT_DIR}/:"
ls -lh "$OUTPUT_DIR"
echo "=========================================================="
