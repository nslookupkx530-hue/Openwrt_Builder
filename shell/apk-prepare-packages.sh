#!/bin/bash

# ==============================================================================
# 脚本名称: apk-prepare-packages.sh
# 描述: 
#   1. 从 wukongdaily/apk 仓库获取第三方 APK 软件包
#   2. 智能识别架构 (兼容 X86, ARM64, ARM64-A53, 以及各种 ARM 变体)
#   3. 逻辑 A (动态): 若存在 .run 脚本，则执行脚本并提取生成的 APK
#   4. 逻辑 B (静态): 若不存在 .run 脚本，则直接提取对应的文件夹内容
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

# --- 步骤 2: 自动判断目标架构 (全平台兼容版) ---
echo "Detecting Architecture..."

# 获取 .config 中启用的 CONFIG_TARGET_xxx 变量名
TARGET_LINE=$(grep '^CONFIG_TARGET_' "${SOURCE_DIR}/.config" | grep "=y" | head -n1)

if [ -n "${TARGET_LINE}" ]; then
    # 提取目标名称 (例如从 CONFIG_TARGET_arm64_a53=y 提取出 arm64_a53)
    RAW_TARGET=$(echo "${TARGET_LINE}" | cut -d'_' -f2-)
    
    if [[ "$RAW_TARGET" == *"x86_64"* ]]; then
        ARCH="x86"
    elif [[ "$RAW_TARGET" == *"arm64_a53"* ]]; then
        ARCH="arm64-a53"
    elif [[ "$RAW_TARGET" == *"arm64"* ]]; then
        ARCH="arm64"
    elif [[ "$RAW_TARGET" == *"arm"* ]]; then
        # 针对 arm/7193, arm/970 等，通常仓库对应的是 arm 文件夹
        if [ -d "${APK_REPO_DIR}/run/arm" ]; then
            ARCH="arm"
        else
            ARCH="arm" # 保底
        fi
    else
        # 处理其他可能存在的平台 (如 mips, mvp 等)
        # 尝试直接匹配，如果没匹配到，默认给一个 arm 保底
        if [ -d "${APK_REPO_DIR}/run/${RAW_TARGET}" ]; then
            ARCH="${RAW_TARGET}"
        elif [ -d "${APK_REPO_DIR}/run/mips" ]; then
            ARCH="mips"
        else
            ARCH="arm"
            echo "Warning: Target ${RAW_TARGET} not explicitly mapped. Defaulting to 'arm'."
        fi
    fi
else
    # 如果 .config 没写清楚，则扫一遍仓库看看有哪些文件夹，选一个最匹配的
    echo "Warning: Could not find CONFIG_TARGET in .config. Scanning repository..."
    FOLDERS=$(ls "${APK_REPO_DIR}/run" 2>/dev/null)
    if echo "$FOLDERS" | grep -q "arm"; then
        ARCH="arm"
    elif echo "$FOLDERS" | grep -q "x86"; then
        ARCH="x86"
    else
        ARCH="arm"
    fi
fi

echo "Final Architecture detected: ${ARCH}"

# --- 步骤 3: 循环处理每个指定的 APK 包 ---
for PACKAGE in $(echo "${CUSTOM_PACKAGES}" | xargs); do
    echo
    echo "=========================================="
    echo "Prepare ${PACKAGE}"
    echo "=========================================="

    # 定义基础路径
    RUN_PATH_DIR="${APK_REPO_DIR}/run/${ARCH}"
    
    # 1. 尝试寻找 .run 脚本 (动态模式)
    RUN_FILE=$(find "${RUN_PATH_DIR}" -name "${PACKAGE}*.run" | head -n1)

    if [ -n "${RUN_FILE}" ]; then
        echo "Mode: Dynamic (.run script found)"
        WORK="/tmp/${PACKAGE}-run"
        rm -rf "${WORK}"
        mkdir -p "${WORK}"

        sh "${RUN_FILE}" \
            --target "${WORK}" \
            --noexec

        echo "Collect dynamic apks..."
        find "${WORK}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
        echo "Successfully prepared: ${PACKAGE} (via .run)"

    else
        # 2. 尝试寻找对应的文件夹 (静态模式)
        # 逻辑：在 run/${ARCH}/ 下寻找包含包名的文件夹
        STATIC_DIR=$(find "${RUN_PATH_DIR}" -maxdepth 1 -type d -name "${PACKAGE}*" | head -n1)

        if [ -n "${STATIC_DIR}" ]; then
            echo "Mode: Static (folder found in run/${ARCH}/)"
            find "${STATIC_DIR}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
            echo "Successfully prepared: ${PACKAGE} (via directory)"
        else
            # 最后的保底：在整个仓库中深度搜索（防止架构映射稍微偏差）
            echo "Warning: No local folder found for ${PACKAGE} in ${ARCH}. Searching entire repo..."
            FINAL_SEARCH=$(find "${APK_REPO_DIR}" -maxdepth 3 -type d -name "${PACKAGE}*" | head -n1)
            if [ -n "${FINAL_SEARCH}" ]; then
                find "${FINAL_SEARCH}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
                echo "Successfully prepared: ${PACKAGE} (via deep search)"
            else
                echo "Error: Package ${PACKAGE} not found in repository."
                echo "Skipping..."
                continue
            fi
        fi
    done
done

# --- 步骤 4: 任务完成总结 ---
echo
echo "APK packages prepared in: ${OUTPUT_DIR}"
if [ -d "${OUTPUT_DIR}" ] && [ "$(ls -A ${OUTPUT_DIR})" ]; then
    ls -lh "${OUTPUT_DIR}"
else
    echo "No APK packages were successfully prepared."
fi
