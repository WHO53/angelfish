#!/usr/bin/env bash

set -e

export GIT_CLONE_ARGS="--depth 1 --single-branch"
export FLATPAK_DIR="$(readlink -f $(dirname $0))"
cd ${FLATPAK_DIR}

if [ ! -d flatpak-builder-tools ]; then
        git clone ${GIT_CLONE_ARGS} https://github.com/flatpak/flatpak-builder-tools
fi
if [ ! -d corrosion ]; then
        git clone ${GIT_CLONE_ARGS} https://github.com/AndrewGaspar/corrosion
fi

./flatpak-builder-tools/cargo/flatpak-cargo-generator.py -o corrosion-generated-sources.json corrosion/generator/Cargo.lock
./flatpak-builder-tools/cargo/flatpak-cargo-generator.py -o generated-sources.json ../Cargo.lock
