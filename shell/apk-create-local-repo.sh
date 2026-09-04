#!/bin/bash

set -e

SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_DIR="${SOURCE_DIR}/packages"
REPO_DIR="${SOURCE_DIR}/packages"

echo "=========================================="
echo "       Create local APK repository"
echo "=========================================="

if [ ! -d "${PACKAGE_DIR}" ]; then
    echo "❌ Package directory does not exist:"
    echo "${PACKAGE_DIR}"
    exit 1
fi

APK_COUNT=$(find "${PACKAGE_DIR}" -maxdepth 1 -type f -name "*.apk" | wc -l)

if [ "${APK_COUNT}" -eq 0 ]; then
    echo "❌ No APK files found."
    exit 1
fi

echo "Found ${APK_COUNT} APK files."

# ------------------------------------------------------------
# 检查 apk 工具
# ------------------------------------------------------------

if ! command -v apk >/dev/null 2>&1; then
    echo "❌ apk command not found."
    exit 1
fi

# ------------------------------------------------------------
# 显示 APK 信息
# ------------------------------------------------------------

echo
echo "Third-party APK files:"

find "${PACKAGE_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.apk" \
    -printf '%f\n' \
    | sort

# ------------------------------------------------------------
# 创建 APK v3 repository index
# ------------------------------------------------------------

echo
echo "🔨 Creating Packages.adb..."

cd "${PACKAGE_DIR}"

apk index \
    --output Packages.adb \
    ./*.apk

echo
echo "✅ Packages.adb created:"
ls -lh Packages.adb
