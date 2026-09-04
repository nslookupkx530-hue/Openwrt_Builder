#!/bin/bash

set -e

SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

BASE_DIR="${SOURCE_DIR}/extra-packages"
TEMP_DIR="${BASE_DIR}/temp-unpack"
PACKAGE_DIR="${SOURCE_DIR}/packages"

APK_REPO="https://github.com/wukongdaily/apk.git"
APK_REPO_DIR="/tmp/wukongdaily-apk"

echo "=========================================="
echo "      Prepare third-party APK packages"
echo "=========================================="

# ------------------------------------------------------------
# 检查 CUSTOM_PACKAGES
# ------------------------------------------------------------

CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"

if [ -z "${CUSTOM_PACKAGES// }" ]; then
    echo "ℹ️ CUSTOM_PACKAGES 为空"
    echo "ℹ️ 未启用第三方预编译 APK"
    exit 0
fi

echo "CUSTOM_PACKAGES:"
echo "${CUSTOM_PACKAGES}"

# ------------------------------------------------------------
# 判断架构
# ------------------------------------------------------------

ARCH="${TARGET_ARCH:-${ARCH:-}}"

if [ -z "$ARCH" ]; then
    if [ -f "${SOURCE_DIR}/.config" ]; then
        ARCH="$(
            grep '^CONFIG_ARCH=' "${SOURCE_DIR}/.config" \
            | cut -d '"' -f 2
        )"
    fi
fi

echo "Detected ARCH: ${ARCH}"

case "${ARCH}" in

    x86_64)
        RUN_ARCH="x86"
        ;;

    aarch64_cortex-a53)
        RUN_ARCH="arm64-a53"
        ;;

    aarch64)
        RUN_ARCH="arm64"
        ;;

    *)
        echo "❌ 不支持的架构: ${ARCH}"
        exit 1
        ;;

esac

echo "Selected third-party APK architecture: ${RUN_ARCH}"

# ------------------------------------------------------------
# 清理目录
# ------------------------------------------------------------

rm -rf "${BASE_DIR}"
rm -rf "${PACKAGE_DIR}"

mkdir -p "${BASE_DIR}"
mkdir -p "${TEMP_DIR}"
mkdir -p "${PACKAGE_DIR}"

# ------------------------------------------------------------
# 下载第三方 APK 仓库
# ------------------------------------------------------------

rm -rf "${APK_REPO_DIR}"

echo "🔄 Cloning third-party APK repository..."

git clone \
    --depth=1 \
    "${APK_REPO}" \
    "${APK_REPO_DIR}"

RUN_DIR="${APK_REPO_DIR}/run/${RUN_ARCH}"

if [ ! -d "${RUN_DIR}" ]; then
    echo "❌ 找不到架构目录:"
    echo "${RUN_DIR}"
    exit 1
fi

echo "✅ Third-party repository:"
echo "${RUN_DIR}"

# ------------------------------------------------------------
# 复制对应架构的 run / apk
# ------------------------------------------------------------

echo "📦 Copying ${RUN_ARCH} packages..."

find "${RUN_DIR}" \
    -maxdepth 1 \
    -type f \
    \( -name "*.run" -o -name "*.apk" \) \
    -exec cp -v {} "${BASE_DIR}/" \;

# ------------------------------------------------------------
# 解包 .run
# ------------------------------------------------------------

for RUN_FILE in "${BASE_DIR}"/*.run; do

    [ -e "${RUN_FILE}" ] || continue

    echo
    echo "🧩 Extracting:"
    echo "${RUN_FILE}"

    sh "${RUN_FILE}" \
        --target "${TEMP_DIR}" \
        --noexec \
        --nochown

done

# ------------------------------------------------------------
# 收集 .apk
# ------------------------------------------------------------

echo
echo "📦 Collecting APK files..."

find "${TEMP_DIR}" \
    -type f \
    -name "*.apk" \
    -exec cp -v {} "${PACKAGE_DIR}/" \;

find "${BASE_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.apk" \
    -exec cp -v {} "${PACKAGE_DIR}/" \;

# ------------------------------------------------------------
# 检查 APK
# ------------------------------------------------------------

APK_COUNT=$(find "${PACKAGE_DIR}" -type f -name "*.apk" | wc -l)

echo
echo "=========================================="
echo "Third-party APK count: ${APK_COUNT}"
echo "=========================================="

if [ "${APK_COUNT}" -eq 0 ]; then
    echo "❌ 没有找到任何 APK"
    exit 1
fi

# ------------------------------------------------------------
# 显示 APK
# ------------------------------------------------------------

find "${PACKAGE_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.apk" \
    -printf '%f\n' \
    | sort

echo
echo "✅ Third-party APK preparation completed."
