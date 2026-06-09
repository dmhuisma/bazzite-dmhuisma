#!/usr/bin/env bash
set -euo pipefail

REAPER_VERSION="7.73"
REAPER_VERSION_COMPACT="${REAPER_VERSION//./}"
REAPER_MAJOR="${REAPER_VERSION%%.*}.x"
ARCHIVE="reaper${REAPER_VERSION_COMPACT}_linux_x86_64.tar.xz"
DOWNLOAD_URL="https://www.reaper.fm/files/${REAPER_MAJOR}/${ARCHIVE}"
INSTALL_DIR="/opt/reaper"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "==> Installing REAPER ${REAPER_VERSION}..."
curl -L --fail --progress-bar "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}"
tar -xJf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"

rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cp -a "${TMP_DIR}/reaper_linux_x86_64/REAPER/." "${INSTALL_DIR}/"

install -d /usr/bin
ln -sf "${INSTALL_DIR}/reaper" /usr/bin/reaper

echo "==> REAPER ${REAPER_VERSION} installed to ${INSTALL_DIR}"
