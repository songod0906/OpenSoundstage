#!/bin/zsh

set -euo pipefail

project_dir=${0:A:h:h}
configuration=${CONFIGURATION:-release}
app_dir="$project_dir/dist/OpenSoundstage.app"
contents_dir="$app_dir/Contents"
binary_path="$project_dir/.build/$configuration/OpenSoundstage"

cd "$project_dir"
swift build -c "$configuration"

if [[ "$app_dir" != "$project_dir/dist/OpenSoundstage.app" ]]; then
    print -u2 "Unexpected app output path."
    exit 1
fi
rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_path" "$contents_dir/MacOS/OpenSoundstage"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"

identity=${SIGN_IDENTITY:--}
codesign --force --deep --sign "$identity" "$app_dir"

printf 'Built %s\n' "$app_dir"
