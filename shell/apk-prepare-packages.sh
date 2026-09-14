#!/bin/bash

# ==============================================================================
# 脚本名称: apk-prepare-packages.sh
# 描述: 
#   1. 从 wukongdaily/apk 仓库获取第三方 APK 软件包
#   2. 根据当前编译架构 (x86, arm64, arm64-a53) 选择对应的 .run 脚本
#   3. 执行 .run 脚本并提取生成的 APK 文件到目标目录
# ==============================================================================

set -euxo pipefail

# --- 基础变量初始化 ---
# SOURCE_DIR: 源码根目录 (默认为当前目录)
SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

# CUSTOM_PACKAGES: 需要处理的第三方 APK 包名称列表 (通过环境变量传入)
CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"

# BASE_DIR: 下载 APK 仓库的临时目录
BASE_DIR="${SOURCE_DIR}/extra-packages"

# OUTPUT_DIR: 最终放置 APK 文件的目录
OUTPUT_DIR="${SOURCE_DIR}/packages"

# APK 仓库地址
REPO="https://github.com/wukongdaily/apk.git"

echo "=========================================="
echo " Prepare third-party APK packages"
echo "=========================================="

# --- 检查输入参数 ---
# 如果环境变量 CUSTOM_PACKAGES 为空，则直接退出
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
# 我们根据 .config 文件中的 CONFIG_TARGET_xxx 来映射到 wukongdaily/apk 目录结构
# 映射规则：
# - CONFIG_TARGET_x86_64=y  =>  x86
# - CONFIG_TARGET_arm64_a53=y =>  arm64-a53
# - CONFIG_TARGET_arm64=y     =>  arm64
echo "Detecting Architecture..."

if grep -q '^CONFIG_TARGET_x86_64=y' "${SOURCE_DIR}/.config"; then
    ARCH="x86"
elif grep -q '^CONFIG_TARGET_arm64_a53=y' "${SOURCE_DIR}/.config"; then
    ARCH="arm64-a53"
elif grep -q '^CONFIG_TARGET_arm64=y' "${SOURCE_DIR}/.config"; then
    ARCH="arm64"
else
    echo "Error: Unsupported architecture detected in .config."
    echo "Please ensure CONFIG_TARGET_xxx=y is correctly set in your .config file."
    exit 1
fi

echo "Architecture detected: ${ARCH}"

# --- 步骤 3: 循环处理每个指定的 APK 包 ---
for PACKAGE in ${CUSTOM_PACKAGES}
do
    echo
    echo "=========================================="
    echo "Prepare ${PACKAGE}"
    echo "=========================================="

    # 寻找对应架构的 .run 脚本
    # 使用 find 命令在对应的架构目录下搜索包含包名的 .run 文件
    RUN_FILE=$(find \
        "${APK_REPO_DIR}/run/${ARCH}" \
        -name "${PACKAGE}*.run" \
        | head -n1)

    if [ -z "${RUN_FILE}" ]; then
        echo "Error: Missing run file for package: ${PACKAGE}"
        echo "Checked path: ${APK_REPO_DIR}/run/${ARCH}"
        exit 1
    fi

    echo "Found run file: ${RUN_FILE}"

    # 创建临时工作目录
    WORK="/tmp/${PACKAGE}-run"
    rm -rf "${WORK}"
    mkdir -p "${WORK}"

    # 执行 .run 脚本
    # --target 指定生成的 APK 存放位置
    # --noexec 防止由于 CI 环境权限问题导致无法直接执行二进制
    sh "${RUN_FILE}" \
        --target "${WORK}" \
        --noexec

    echo "Collect apk files..."

    # 将生成的所有 .apk 文件复制到最终输出目录
    find "${WORK}" \
        -name "*.apk" \
        -exec cp {} "${OUTPUT_DIR}/" \;

done

# --- 步骤 4: 任务完成总结 ---
echo
echo "APK packages prepared in: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"
