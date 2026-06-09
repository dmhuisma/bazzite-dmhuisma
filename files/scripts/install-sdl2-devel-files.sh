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
    version="$(rpm -q --qf '%{VERSION}-%{RELEASE}' "sdl2-compat.${arch}")"

    echo "==> Downloading sdl2-compat-devel-${version}.${arch} without dependency resolution..."
    if ! dnf5 download \
        --destdir "${download_dir}" \
        --arch "${arch}" \
        "sdl2-compat-devel-${version}.${arch}"; then
        echo "==> Exact sdl2-compat-devel match was unavailable; downloading latest ${arch} package..."
        dnf5 download \
            --destdir "${download_dir}" \
            --arch "${arch}" \
            sdl2-compat-devel
    fi

    rpm_path="$(find "${download_dir}" -maxdepth 1 -name "sdl2-compat-devel-*.${arch}.rpm" -print -quit)"
    if [[ -z "${rpm_path}" ]]; then
        echo "ERROR: Could not find downloaded sdl2-compat-devel RPM for ${arch}." >&2
        exit 1
    fi

    echo "==> Extracting sdl2-compat-devel files for ${arch}..."
    rpm2cpio "${rpm_path}" | cpio -idm --quiet -D /
}

install_pkgconfig_shim() {
    local libdir="$1"
    local source_pc=""

    if [[ -f "${libdir}/pkgconfig/sdl2-compat.pc" ]]; then
        source_pc="sdl2-compat.pc"
    elif [[ -f "${libdir}/pkgconfig/sdl2_compat.pc" ]]; then
        source_pc="sdl2_compat.pc"
    else
        return 0
    fi

    ln -sf "${source_pc}" "${libdir}/pkgconfig/sdl2.pc"
}

extract_sdl2_devel x86_64
extract_sdl2_devel i686

install_pkgconfig_shim /usr/lib64
install_pkgconfig_shim /usr/lib

pkg-config --exists sdl2
PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig pkg-config --exists sdl2

echo "==> SDL2 development files installed for Zephyr native_sim builds."
