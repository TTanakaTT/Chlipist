#!/bin/sh

set -eu

if [ "$#" -ne 4 ]; then
	echo "usage: $0 APP_PATH DMG_STAGING_PATH DMG_PATH DMG_VOLUME_NAME" >&2
	exit 1
fi

app_path="$1"
dmg_staging_path="$2"
dmg_path="$3"
dmg_volume_name="$4"

rm -rf "$dmg_staging_path"
rm -f "$dmg_path"
mkdir -p "$dmg_staging_path"
cp -R "$app_path" "$dmg_staging_path/Chlipist.app"
ln -s /Applications "$dmg_staging_path/Drag To Applications"

hdiutil create \
	-volname "$dmg_volume_name" \
	-srcfolder "$dmg_staging_path" \
	-ov \
	-format UDZO \
	"$dmg_path"

hdiutil verify "$dmg_path"
