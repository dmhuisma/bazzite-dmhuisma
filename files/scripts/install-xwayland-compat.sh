#!/usr/bin/env bash

set -euo pipefail

# Bazzite ships terra-xorg-x11-server-Xwayland, whose 26.x builds provide
# xorg-x11-server-Xwayland but not the arch-qualified
# xorg-x11-server-Xwayland(x86-64) that Fedora-style packages (e.g. the
# LionHeartP hyprland package) require. Install an empty package that adds
# the missing provide on top of the installed Xwayland.

ISA_PROVIDE="xorg-x11-server-Xwayland(x86-64)"

if rpm -q --whatprovides "$ISA_PROVIDE" >/dev/null 2>&1; then
    echo "${ISA_PROVIDE} is already provided; nothing to do."
    exit 0
fi

read -r name version release < <(
    rpm -q --whatprovides xorg-x11-server-Xwayland \
        --queryformat '%{name} %{version} %{release}\n' | head -n1
)

TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

cat >"${TMP_DIR}/xwayland-isa-compat.spec" <<SPEC
Name:           xwayland-isa-compat
Version:        ${version}
Release:        ${release}
Summary:        Arch-qualified Xwayland provide for ${name}
License:        MIT
Requires:       ${name}(x86-64) = ${version}-${release}
Provides:       ${ISA_PROVIDE} = ${version}-${release}

%description
Adds the ${ISA_PROVIDE} provide missing from ${name}.

%files
SPEC

dnf5 -y install rpm-build

rpmbuild -bb \
    --define "_topdir ${TMP_DIR}/rpmbuild" \
    "${TMP_DIR}/xwayland-isa-compat.spec"

dnf5 -y remove rpm-build

dnf5 -y install "${TMP_DIR}"/rpmbuild/RPMS/x86_64/xwayland-isa-compat-*.rpm

rpm -q --whatprovides "$ISA_PROVIDE"
