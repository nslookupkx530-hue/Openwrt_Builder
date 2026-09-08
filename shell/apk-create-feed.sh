#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages"


echo "=========================================="
echo "Create third-party APK repository"
echo "=========================================="


mkdir -p "${PACKAGE_DIR}"


cd "${PACKAGE_DIR}"


echo "Generate APK repository"


apk index \
    --output packages.adb \
    *.apk


echo

echo "=========================================="
echo "Third-party APK repository created"
echo "=========================================="


ls -lah
