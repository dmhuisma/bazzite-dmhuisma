#!/usr/bin/env bash
set -euo pipefail

LATEST_RELEASE_URL="https://github.com/wineasio/wineasio/releases/latest"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

find_wine_dir() {
    local subdir="$1"
    local marker="$2"
    local path=""

    while IFS= read -r path; do
        case "${path}" in
            */wine/"${subdir}/${marker}")
                dirname "${path}"
                return 0
                ;;
        esac
    done < <(rpm -ql wine-core wine 2>/dev/null || true)

    path="$(find /usr/lib64 /usr/lib /opt -path "*/wine/${subdir}/${marker}" -print -quit 2>/dev/null || true)"
    if [[ -n "${path}" ]]; then
        dirname "${path}"
        return 0
    fi

    echo "ERROR: Could not find Wine ${subdir} library directory." >&2
    exit 1
}

echo "==> Resolving latest WineASIO release..."
LATEST_URL=$(curl -Ls -o /dev/null -w '%{url_effective}' "${LATEST_RELEASE_URL}")
LATEST_URL="${LATEST_URL%%\?*}"
WINEASIO_TAG="${LATEST_URL##*/}"
WINEASIO_VERSION="${WINEASIO_TAG#v}"

if [[ -z "${WINEASIO_TAG}" || "${WINEASIO_TAG}" == "latest" ]]; then
    echo "ERROR: Could not determine latest WineASIO version from ${LATEST_RELEASE_URL}" >&2
    exit 1
fi

ARCHIVE="wineasio-${WINEASIO_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/wineasio/wineasio/archive/refs/tags/${WINEASIO_TAG}.tar.gz"
SOURCE_DIR="${TMP_DIR}/wineasio-${WINEASIO_VERSION}"
WINE64_WINDOWS_DIR="$(find_wine_dir x86_64-windows ntdll.dll)"
WINE64_UNIX_DIR="$(find_wine_dir x86_64-unix ntdll.so)"
WINEBUILD_INCLUDE_DIR="$(find /usr/include -path '*/wine/windows' -type d -print -quit 2>/dev/null || true)"
WINEBUILD_LIB_DIR="${WINE64_UNIX_DIR}"

if [[ -z "${WINEBUILD_INCLUDE_DIR}" ]]; then
    echo "ERROR: Could not find Wine development headers." >&2
    exit 1
fi

echo "==> Building WineASIO ${WINEASIO_VERSION}..."
curl -L --fail --progress-bar "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE}"
tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"

make -C "${SOURCE_DIR}" 64 \
    WINEBUILD_INCLUDEDIR="${WINEBUILD_INCLUDE_DIR}" \
    WINEBUILD_LIBDIR="${WINEBUILD_LIB_DIR}"

install -d \
    "${WINE64_WINDOWS_DIR}" \
    "${WINE64_UNIX_DIR}" \
    /usr/bin

install -m 0644 "${SOURCE_DIR}/build64/wineasio64.dll" "${WINE64_WINDOWS_DIR}/wineasio64.dll"
install -m 0644 "${SOURCE_DIR}/build64/wineasio64.dll.so" "${WINE64_UNIX_DIR}/wineasio64.dll.so"
install -m 0755 "${SOURCE_DIR}/wineasio-register" /usr/bin/wineasio-register-upstream

cat > /usr/bin/wineasio-register << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 || -z "${1:-}" ]]; then
    echo "Usage: wineasio-register WINEPREFIX" >&2
    exit 2
fi

exec wineasio-register-prefix "$1"
EOF
chmod 0755 /usr/bin/wineasio-register

echo "==> WineASIO ${WINEASIO_VERSION} installed to ${WINE64_UNIX_DIR}"
