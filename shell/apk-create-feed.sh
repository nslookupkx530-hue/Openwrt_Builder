#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages"


APK_TOOL="${SOURCE_DIR}/staging_dir/host/bin/apk"


echo "=========================================="
echo "Create third-party APK repository"
echo "=========================================="


if [ ! -x "${APK_TOOL}" ]; then

    echo "Missing apk tool:"
    echo "${APK_TOOL}"

    exit 1

fi



echo "APK tool:"
echo "${APK_TOOL}"



mkdir -p "${PACKAGE_DIR}"



cd "${PACKAGE_DIR}"



echo "Generate APK repository index"


"${APK_TOOL}" index \
    --output packages.adb \
    *.apk



echo

echo "=========================================="
echo "Third-party APK repository created"
echo "=========================================="


ls -lah
