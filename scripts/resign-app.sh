#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: $0 APP_PATH" >&2
	exit 1
fi

app_path="$1"

codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"