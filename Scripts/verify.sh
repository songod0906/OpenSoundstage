#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}

cd "$project_dir"
swift package dump-package >/dev/null
plutil -lint Resources/Info.plist
zsh -n Scripts/build-app.sh Scripts/verify.sh
git diff --check
git show --check --format='' HEAD
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test -c release
Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 dist/OpenSoundstage.app
test -f dist/OpenSoundstage.app/Contents/Resources/AppIcon.icns

printf 'Verification passed.\n'
