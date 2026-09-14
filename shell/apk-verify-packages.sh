#!/bin/bash
# 实际作用是验证 APK，不创建 packages.adb
set -euo pipefail

SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages"

echo "=========================================="
echo "Prepare third-party APK repository"
echo "=========================================="

if [ ! -d "${PACKAGE_DIR}" ]; then

    echo "Missing package directory"

    exit 1

fi

echo "Third-party APK packages:"

ls -lah "${PACKAGE_DIR}"

echo

echo "Repository preparation completed"
