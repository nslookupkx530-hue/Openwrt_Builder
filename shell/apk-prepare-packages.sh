#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"


CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"


BASE_DIR="${SOURCE_DIR}/extra-packages"

OUTPUT_DIR="${SOURCE_DIR}/packages"


REPO="https://github.com/wukongdaily/apk.git"


echo "=========================================="
echo " Prepare third-party APK packages"
echo "=========================================="


if [ -z "${CUSTOM_PACKAGES// }" ]; then

    echo "No third-party APK packages"

    exit 0

fi



rm -rf "${BASE_DIR}"

rm -rf "${OUTPUT_DIR}"


mkdir -p "${BASE_DIR}"
mkdir -p "${OUTPUT_DIR}"



echo "Clone APK repository"

APK_REPO_DIR="/tmp/wukongdaily-apk"
rm -rf "${APK_REPO_DIR}"

git clone \
    --depth=1 \
    https://github.com/wukongdaily/apk.git \
    "${APK_REPO_DIR}"



# 自动判断架构

if grep -q '^CONFIG_TARGET_x86_64=y' "${SOURCE_DIR}/.config"; then

    ARCH="x86"

elif grep -q '^CONFIG_TARGET_arm64=y' "${SOURCE_DIR}/.config"; then

    ARCH="arm64"

else

    echo "Unsupported architecture"

    exit 1

fi



echo "Architecture:"
echo "${ARCH}"



for PACKAGE in ${CUSTOM_PACKAGES}

do

    echo
    echo "=========================================="
    echo "Prepare ${PACKAGE}"
    echo "=========================================="


    RUN_FILE=$(find \
        /tmp/wukongdaily-apk/run/${ARCH} \
        -name "${PACKAGE}*.run" \
        | head -n1)



    if [ -z "${RUN_FILE}" ]; then

        echo "Missing run file:"
        echo "${PACKAGE}"

        exit 1

    fi



    WORK="/tmp/${PACKAGE}-run"


    rm -rf "${WORK}"

    mkdir -p "${WORK}"



    sh "${RUN_FILE}" \
        --target "${WORK}" \
        --noexec



    echo "Collect apk"



    find "${WORK}" \
        -name "*.apk" \
        -exec cp {} "${OUTPUT_DIR}/" \;



done



echo

echo "APK packages:"


ls -lh "${OUTPUT_DIR}"
