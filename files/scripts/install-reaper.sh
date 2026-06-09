#!/usr/bin/env bash
set -euo pipefail

DOWNLOAD_PAGE="https://www.reaper.fm/download.php"
INSTALL_DIR="/opt/reaper"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "==> Resolving latest REAPER Linux x86_64 release..."
DOWNLOAD_PAGE_HTML=$(curl -fsSL "${DOWNLOAD_PAGE}")
DOWNLOAD_PATH=$(grep -m1 -oE '/?files/[0-9]+\.x/reaper[0-9]+_linux_x86_64\.tar\.xz' <<< "${DOWNLOAD_PAGE_HTML}")

if [[ -z "${DOWNLOAD_PATH}" ]]; then
    echo "ERROR: Could not find latest REAPER Linux x86_64 download on ${DOWNLOAD_PAGE}" >&2
    exit 1
fi

ARCHIVE="${DOWNLOAD_PATH##*/}"
DOWNLOAD_URL="https://www.reaper.fm/${DOWNLOAD_PATH#/}"
REAPER_VERSION_COMPACT="${ARCHIVE#reaper}"
REAPER_VERSION_COMPACT="${REAPER_VERSION_COMPACT%%_linux_x86_64.tar.xz}"
REAPER_MAJOR="${DOWNLOAD_PATH#/}"
REAPER_MAJOR="${REAPER_MAJOR#files/}"
REAPER_MAJOR="${REAPER_MAJOR%%.x/*}"

if [[ -z "${REAPER_MAJOR}" || "${REAPER_VERSION_COMPACT}" != "${REAPER_MAJOR}"* ]]; then
    echo "ERROR: Could not parse REAPER version from ${ARCHIVE}" >&2
    exit 1
fi

REAPER_VERSION_MINOR="${REAPER_VERSION_COMPACT#"${REAPER_MAJOR}"}"
REAPER_VERSION="${REAPER_MAJOR}.${REAPER_VERSION_MINOR}"

echo "==> Installing REAPER ${REAPER_VERSION}..."
curl -L --fail --progress-bar "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}"
tar -xJf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"

rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cp -a "${TMP_DIR}/reaper_linux_x86_64/REAPER/." "${INSTALL_DIR}/"

install -d /usr/bin
ln -sf "${INSTALL_DIR}/reaper" /usr/bin/reaper

echo "==> REAPER ${REAPER_VERSION} installed to ${INSTALL_DIR}"
