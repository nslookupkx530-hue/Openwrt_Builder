#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages"

APK_TOOL="${SOURCE_DIR}/staging_dir/host/bin/apk"


echo "=========================================="
echo "Create third-party APK repository"
echo "=========================================="


if [ ! -x "${APK_TOOL}" ]; then

    echo "Build OpenWrt apk host tool"

    make package/system/apk/host/compile V=s

fi


if [ ! -x "${APK_TOOL}" ]; then

    echo "Missing apk tool:"
    echo "${APK_TOOL}"
    exit 1
fi


cd "${PACKAGE_DIR}"


echo "Generate APK repository"


"${APK_TOOL}" index \
    --allow-untrusted \
    --output packages.adb \
    *.apk


echo

echo "=========================================="
echo "Third-party APK repository created"
echo "=========================================="


ls -lah
