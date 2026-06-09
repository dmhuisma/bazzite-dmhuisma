#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

extract_sdl2_devel() {
    local arch="$1"
    local download_dir="${TMP_DIR}/${arch}"
    local version=""
    local rpm_path=""

    mkdir -p "${download_dir}"
    version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "SDL2.${arch}")"

    echo "==> Downloading SDL2-devel-${version}.${arch} without dependency resolution..."
    if ! dnf5 download \
        --destdir "${download_dir}" \
        --arch "${arch}" \
        "SDL2-devel-${version}.${arch}"; then
        echo "==> Exact SDL2-devel match was unavailable; downloading latest ${arch} package..."
        dnf5 download \
            --destdir "${download_dir}" \
            --arch "${arch}" \
            SDL2-devel
    fi

    rpm_path="$(find "${download_dir}" -maxdepth 1 -name "SDL2-devel-*.${arch}.rpm" -print -quit)"
    if [[ -z "${rpm_path}" ]]; then
        echo "ERROR: Could not find downloaded SDL2-devel RPM for ${arch}." >&2
        exit 1
    fi

    echo "==> Extracting SDL2-devel files for ${arch}..."
    rpm2cpio "${rpm_path}" | cpio -idm --quiet -D /
}

extract_sdl2_devel x86_64
extract_sdl2_devel i686

pkg-config --exists sdl2
PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig pkg-config --exists sdl2

echo "==> SDL2 development files installed for Zephyr native_sim builds."
