#!/usr/bin/env bash

set -euo pipefail

echo "Installed Mesa GBM package:"
rpm -q mesa-libgbm

# terra-mesa is present in Bazzite, but disabled by default.
dnf5 -y \
    --enable-repo=terra-mesa \
    install mesa-libgbm-devel.x86_64

echo "Installed development package:"
rpm -q mesa-libgbm-devel

pkg-config --exists gbm
echo "GBM pkg-config version: $(pkg-config --modversion gbm)"
