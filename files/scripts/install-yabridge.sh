#!/usr/bin/env bash
set -euo pipefail

YABRIDGE_VERSION="5.1.1"
ARCHIVE="yabridge-${YABRIDGE_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_VERSION}/${ARCHIVE}"
INSTALL_DIR="/opt/yabridge"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "==> Installing yabridge ${YABRIDGE_VERSION}..."
curl -L --fail --progress-bar "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}"

rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "${TMP_DIR}/${ARCHIVE}" --strip-components=1 -C "${INSTALL_DIR}"

install -d /usr/bin
ln -sf "${INSTALL_DIR}/yabridgectl" /usr/bin/yabridgectl
ln -sf "${INSTALL_DIR}/yabridge-host.exe" /usr/bin/yabridge-host.exe
ln -sf "${INSTALL_DIR}/yabridge-host-32.exe" /usr/bin/yabridge-host-32.exe

cat > /etc/profile.d/yabridge.sh << 'EOF'
export PATH="/opt/yabridge:${PATH}"
EOF

echo "==> yabridge ${YABRIDGE_VERSION} installed to ${INSTALL_DIR}"
