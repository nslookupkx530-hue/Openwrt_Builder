#!/bin/bash

# ==============================================================================
# 脚本名称: apk-prepare-packages.sh
# 描述: 
#   1. 从 wukongdaily/apk 仓库获取第三方 APK 软件包
#   2. 智能识别模式：
#      - 模式 A (动态): 发现 .run 脚本 -> 执行脚本并提取生成的 APK
#      - 模式 B (静态): 发现对应文件夹 -> 直接提取文件夹内的 APK 文件
#   3. 自动识别架构: x86, arm64, arm64-a53
# ==============================================================================

set -euxo pipefail

# --- 基础变量初始化 ---
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"
CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"
BASE_DIR="${SOURCE_DIR}/extra-packages"
OUTPUT_DIR="${SOURCE_DIR}/packages"
REPO="https://github.com/wukongdaily/apk.git"

echo "=========================================="
echo " Prepare third-party APK packages"
echo "=========================================="

if [ -z "${CUSTOM_PACKAGES// }" ]; then
    echo "No third-party APK packages specified. Skipping..."
    exit 0
fi

# 清理并创建必要的目录
rm -rf "${BASE_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${BASE_DIR}"
mkdir -p "${OUTPUT_DIR}"

# --- 步骤 1: 克隆 APK 仓库 ---
echo "Clone APK repository"
APK_REPO_DIR="/tmp/wukongdaily-apk"
rm -rf "${APK_REPO_DIR}"

git clone \
    --depth=1 \
    "${REPO}" \
    "${APK_REPO_DIR}"

# --- 步骤 2: 自动判断目标架构 ---
echo "Detecting Architecture..."
if grep -q '^CONFIG_TARGET_x86_64=y' "${SOURCE_DIR}/.config"; then
    ARCH="x86"
elif grep -q '^CONFIG_TARGET_arm64_a53=y' "${SOURCE_DIR}/.config"; then
    ARCH="arm64-a53"
elif grep -q '^CONFIG_TARGET_arm64=y' "${SOURCE_DIR}/.config"; then
    ARCH="arm64"
else
    echo "Error: Unsupported architecture detected in .config."
    exit 1
fi

echo "Architecture detected: ${ARCH}"

# --- 步骤 3: 循环处理每个指定的 APK 包 ---
# 使用 xargs 去除可能存在的首尾空格
for PACKAGE in $(echo "${CUSTOM_PACKAGES}" | xargs); do
    echo
    echo "=========================================="
    echo "Prepare ${PACKAGE}"
    echo "=========================================="

    # 路径定义
    RUN_PATH_DIR="${APK_REPO_DIR}/run/${ARCH}"
    
    # 1. 尝试寻找 .run 脚本 (动态模式)
    RUN_FILE=$(find "${RUN_PATH_DIR}" -name "${PACKAGE}*.run" | head -n1)

    if [ -n "${RUN_FILE}" ]; then
        echo "Mode: Dynamic (.run script found)"
        WORK="/tmp/${PACKAGE}-run"
        rm -rf "${WORK}"
        mkdir -p "${WORK}"

        # 执行脚本
        sh "${RUN_FILE}" \
            --target "${WORK}" \
            --noexec

        echo "Collect dynamic apks..."
        find "${WORK}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
        echo "Successfully prepared: ${PACKAGE} (via .run)"

    else
        # 2. 尝试寻找对应文件夹 (静态模式)
        # 这里专门在 run/${ARCH}/ 下寻找匹配的目录，对应您截图中的结构
        STATIC_DIR=$(find "${RUN_PATH_DIR}" -maxdepth 1 -type d -name "${PACKAGE}*" | head -n1)

        if [ -n "${STATIC_DIR}" ]; then
            echo "Mode: Static (folder found in run/${ARCH}/)"
            echo "Source directory: ${STATIC_DIR}"
            find "${STATIC_DIR}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
            echo "Successfully prepared: ${PACKAGE} (via directory)"
        else
            # 如果两者都没找到，才输出警告并跳过
            echo "Warning: No .run script or matching directory found for: ${PACKAGE}"
            echo "Checking repository for any other matches..."
            # 最后的保底搜索：在整个仓库里找
            FINAL_SEARCH=$(find "${APK_REPO_DIR}" -maxdepth 3 -type d -name "${PACKAGE}*" | head -n1)
            if [ -n "${FINAL_SEARCH}" ]; then
                echo "Found alternative directory: ${FINAL_SEARCH}"
                find "${FINAL_SEARCH}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
                echo "Successfully prepared: ${PACKAGE} (via deep search)"
            else
                echo "Skipping ${PACKAGE} - Not found in repository."
            fi
        fi
    fi
done

# --- 步骤 4: 任务完成总结 ---
echo
echo "APK packages prepared in: ${OUTPUT_DIR}"
if [ -d "${OUTPUT_DIR}" ] && [ "$(ls -A ${OUTPUT_DIR})" ]; then
    ls -lh "${OUTPUT_DIR}"
else
    echo "No APK packages were successfully prepared."
fi
