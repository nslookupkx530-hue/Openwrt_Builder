#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages"


echo "=========================================="
echo "Create third-party APK repository"
echo "=========================================="


if [ ! -d "$PACKAGE_DIR" ]; then

    echo "Missing packages directory"

    exit 1

fi


APK_TOOL="${SOURCE_DIR}/staging_dir/host/bin/apk"


if [ ! -x "$APK_TOOL" ]; then

    echo "Missing apk tool"

    exit 1

fi


cd "$PACKAGE_DIR"


echo "Generate packages.adb"


"$APK_TOOL" index \
    --output packages.adb \
    *.apk


echo

ls -lah

echo

echo "Third-party APK repository created"
