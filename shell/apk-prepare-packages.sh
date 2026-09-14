#!/bin/bash

# ============================================================
# ImmortalWrt 25.12.x 第三方 APK 插件配置
# ============================================================
#
# 支持架构: x86, arm64, arm64-a53, arm (通用)
#
# 工作方式:
# 1. 优先寻找 .run 脚本进行动态解包
# 2. 若无脚本，寻找包含核心关键词的静态文件夹并提取 APK
# ============================================================

set -euxo pipefail

# --- 基础变量 ---
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

# 清理并创建目录
rm -rf "${BASE_DIR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${BASE_DIR}"
mkdir -p "${OUTPUT_DIR}"

# --- 步骤 1: 克隆仓库 ---
echo "Clone APK repository"
APK_REPO_DIR="/tmp/wukongdaily-apk"
rm -rf "${APK_REPO_DIR}"
git clone --depth=1 "${REPO}" "${APK_REPO_DIR}"

# --- 步骤 2: 架构检测 ---
echo "Detecting Architecture..."
if grep -q '^CONFIG_TARGET_x86_64=y' "${SOURCE_DIR}/.config"; then
    ARCH="x86"
elif grep -q '^CONFIG_TARGET_arm64_a53=y' "${SOURCE_DIR}/.config"; then
    ARCH="arm64-a53"
elif grep -q '^CONFIG_TARGET_arm64=y' "${SOURCE_DIR}/.config"; then
    ARCH="arm64"
else
    # 自动识别 arm 系列
    if [ -d "${APK_REPO_DIR}/run/arm" ]; then ARCH="arm"; 
    elif [ -d "${APK_REPO_DIR}/run/x86" ]; then ARCH="x86"; 
    else ARCH="arm"; fi
    echo "Warning: Target not explicitly matched. Defaulting to ${ARCH}"
fi
echo "Final Architecture: ${ARCH}"

# --- 步骤 3: 处理包 ---
# 预处理包列表，去掉多余空格
PACKAGES_LIST=$(echo "${CUSTOM_PACKAGES}" | xargs)

for PACKAGE in ${PACKAGES_LIST}; do
    echo
    echo "=========================================="
    echo "Prepare ${PACKAGE}"
    echo "=========================================="

    RUN_PATH_DIR="${APK_REPO_DIR}/run/${ARCH}"
    
    # 1. 尝试找 .run 文件 (动态模式)
    RUN_FILE=$(find "${RUN_PATH_DIR}" -name "${PACKAGE}*.run" | head -n1)
    if [ -n "${RUN_FILE}" ]; then
        echo "Mode: Dynamic (.run script found)"
        WORK="/tmp/${PACKAGE}-run"
        rm -rf "${WORK}" && mkdir -p "${WORK}"
        sh "${RUN_FILE}" --target "${WORK}" --noexec
        find "${WORK}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
        echo "Successfully prepared: ${PACKAGE}"
        continue
    fi

    # 2. 尝试找匹配的文件夹 (静态模式)
    # 逻辑：查找包含 PACKAGE 字符串的文件夹
    STATIC_DIR=$(find "${RUN_PATH_DIR}" -maxdepth 1 -type d -name "*${PACKAGE}*" | head -n1)
    if [ -n "${STATIC_DIR}" ]; then
        echo "Mode: Static (folder found)"
        find "${STATIC_DIR}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
        echo "Successfully prepared: ${PACKAGE}"
        continue
    fi

    # 3. 模糊匹配 (针对 luci-i18n-xxx 匹配 luci-app-xxx)
    # 提取核心关键词 (如从 luci-i18n-quickstart-zh-cn 提取 quickstart)
    # 策略：取最后一部分非数字字母的字符串
    CORE_KEYWORD=$(echo "${PACKAGE}" | grep -oE '[a-zA-Z0-9]+' | tail -n1)
    
    # 如果关键词不是单纯的 "i18n" 或 "zh-cn"，尝试匹配
    if [[ "${CORE_KEYWORD}" != "i18n" && "${CORE_KEYWORD}" != "zh-cn" ]]; then
        FUZZY_DIR=$(find "${RUN_PATH_DIR}" -maxdepth 1 -type d -name "*${CORE_KEYWORD}*" | head -n1)
        if [ -n "${FUZZY_DIR}" ]; then
            echo "Mode: Fuzzy Match (found via keyword: ${CORE_KEYWORD})"
            find "${FUZZY_DIR}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
            echo "Successfully prepared: ${PACKAGE}"
            continue
        fi
    fi

    # 4. 最后的兜底搜索 (在整个仓库里找)
    FINAL_SEARCH=$(find "${APK_REPO_DIR}" -maxdepth 3 -type d -name "*${CORE_KEYWORD}*" | head -n1)
    if [ -n "${FINAL_SEARCH}" ]; then
        echo "Mode: Deep Search (found in repo)"
        find "${FINAL_SEARCH}" -name "*.apk" -exec cp {} "${OUTPUT_DIR}/" \;
        echo "Successfully prepared: ${PACKAGE}"
    else
        echo "Warning: Package ${PACKAGE} not found in repository."
    fi
done

# --- 步骤 4: 总结 ---
echo
echo "APK packages prepared in: ${OUTPUT_DIR}"
if [ -d "${OUTPUT_DIR}" ] && [ "$(ls -A ${OUTPUT_DIR})" ]; then
    ls -lh "${OUTPUT_DIR}"
else
    echo "No APK packages were successfully prepared."
fi
