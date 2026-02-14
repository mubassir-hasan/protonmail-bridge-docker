#!/bin/bash
set -ex

# Repack deb (remove unnecessary dependencies)
mkdir deb
wget -i /PACKAGE -O /deb/protonmail.deb
cd deb
ar x -v protonmail.deb

# Handle both .gz and .xz compression formats
if [ -f control.tar.xz ]; then
    CONTROL_TAR=control.tar.xz
    tar xvf control.tar.xz -C .
elif [ -f control.tar.gz ]; then
    CONTROL_TAR=control.tar.gz
    tar xvf control.tar.gz -C .
elif [ -f control.tar.zst ]; then
    CONTROL_TAR=control.tar.zst
    tar xvf control.tar.zst -C .
fi

sed -i "s/^Depends: .*$/Depends: libgl1, libc6, libsecret-1-0, libfido2-1, libstdc++6, libgcc1/" control

# Repack control with same format
if [ -f control.tar.xz ]; then
    tar cvJf control.tar.xz control
elif [ -f control.tar.gz ]; then
    tar cvzf control.tar.gz control
elif [ -f control.tar.zst ]; then
    tar --zstd -cvf control.tar.zst control
fi

# Find data tar (could be .xz, .gz, or .zst)
DATA_TAR=$(ls data.tar.* 2>/dev/null | head -1)

ar rcs /protonmail.deb debian-binary control.tar.* $DATA_TAR
