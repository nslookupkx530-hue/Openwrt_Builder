#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages/third-party"


if [ ! -d "${PACKAGE_DIR}" ]; then

    echo "No apk repository"

    exit 0

fi



APK_TOOL="${SOURCE_DIR}/staging_dir/host/bin/apk"


if [ ! -x "${APK_TOOL}" ]; then

    echo "apk host tool missing"

    exit 1

fi



cd "${PACKAGE_DIR}"


echo "Generate apk repository index"


"${APK_TOOL}" index \
    -o packages.adb \
    *.apk



echo "Done"

ls -lah
