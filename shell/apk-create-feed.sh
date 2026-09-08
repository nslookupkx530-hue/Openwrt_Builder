#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages"

FEED_DIR="${SOURCE_DIR}/third-party-feed"


APK_TOOL="${SOURCE_DIR}/staging_dir/host/bin/apk"


echo "=========================================="
echo "Create third-party APK repository"
echo "=========================================="


#
# Build apk host tool
#

if [ ! -x "${APK_TOOL}" ]; then

    echo "Build OpenWrt apk host tool"

    cd "${SOURCE_DIR}"

    make package/system/apk/host/compile V=s

fi



if [ ! -x "${APK_TOOL}" ]; then

    echo "apk tool still missing:"
    echo "${APK_TOOL}"

    exit 1

fi



echo "APK tool:"
echo "${APK_TOOL}"



#
# create repository
#

mkdir -p "${FEED_DIR}"


cp \
    "${PACKAGE_DIR}"/*.apk \
    "${FEED_DIR}/"



cd "${FEED_DIR}"



echo "Generate packages.adb"


"${APK_TOOL}" mkndx \
    --root . \
    --allow-untrusted \
    --output packages.adb \
    *.apk



echo

echo "Third-party APK repository created"

ls -lah
