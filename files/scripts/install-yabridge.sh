#!/usr/bin/env bash
set -euo pipefail

LATEST_RELEASE_URL="https://github.com/robbert-vdh/yabridge/releases/latest"
INSTALL_DIR="/opt/yabridge"
TMP_DIR="$(mktemp -d)"

echo "==> Resolving latest yabridge release..."
LATEST_URL=$(curl -Ls -o /dev/null -w '%{url_effective}' "${LATEST_RELEASE_URL}")
LATEST_URL="${LATEST_URL%%\?*}"
YABRIDGE_TAG="${LATEST_URL##*/}"
YABRIDGE_VERSION="${YABRIDGE_TAG#v}"

if [[ -z "${YABRIDGE_TAG}" || "${YABRIDGE_TAG}" == "latest" ]]; then
    echo "ERROR: Could not determine latest yabridge version from ${LATEST_RELEASE_URL}" >&2
    exit 1
fi

ARCHIVE="yabridge-${YABRIDGE_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_TAG}/${ARCHIVE}"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "==> Installing yabridge ${YABRIDGE_VERSION}..."
curl -L --fail --progress-bar "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}"

rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "${TMP_DIR}/${ARCHIVE}" --strip-components=1 -C "${INSTALL_DIR}"

install -d /usr/bin /usr/lib
ln -sf "${INSTALL_DIR}/yabridgectl" /usr/bin/yabridgectl
ln -sf "${INSTALL_DIR}/yabridge-host.exe" /usr/bin/yabridge-host.exe
ln -sf "${INSTALL_DIR}/yabridge-host-32.exe" /usr/bin/yabridge-host-32.exe

for runtime_file in \
    libyabridge-chainloader-clap.so \
    libyabridge-chainloader-vst2.so \
    libyabridge-chainloader-vst3.so \
    libyabridge-clap.so \
    libyabridge-vst2.so \
    libyabridge-vst3.so \
    yabridge-host.exe \
    yabridge-host.exe.so \
    yabridge-host-32.exe \
    yabridge-host-32.exe.so; do
    if [[ ! -e "${INSTALL_DIR}/${runtime_file}" ]]; then
        echo "ERROR: Missing expected yabridge runtime file: ${runtime_file}" >&2
        exit 1
    fi

    ln -sf "${INSTALL_DIR}/${runtime_file}" "/usr/lib/${runtime_file}"
done

cat > /etc/profile.d/yabridge.sh << 'EOF'
export PATH="/opt/yabridge:${PATH}"
EOF

echo "==> yabridge ${YABRIDGE_VERSION} installed to ${INSTALL_DIR}"
