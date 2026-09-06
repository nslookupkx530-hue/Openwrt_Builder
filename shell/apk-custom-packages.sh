#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_ROOT="${SOURCE_DIR}/packages/third-party"

TEMP_DIR="/tmp/wukongdaily-apk"

APK_REPO="https://github.com/wukongdaily/apk.git"


echo "=========================================="
echo " Prepare third-party APK repository"
echo "=========================================="


CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"


if [ -z "${CUSTOM_PACKAGES// }" ]; then

    echo "No third-party APK packages"

    exit 0

fi


echo "CUSTOM_PACKAGES:"
echo "${CUSTOM_PACKAGES}"


mkdir -p "${PACKAGE_ROOT}"


# ============================================================
# Detect architecture
# ============================================================


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



# ============================================================
# Clone apk repository
# ============================================================


rm -rf "${TEMP_DIR}"


git clone \
    --depth=1 \
    "${APK_REPO}" \
    "${TEMP_DIR}"



RUN_DIR="${TEMP_DIR}/run/${ARCH}"


if [ ! -d "${RUN_DIR}" ]; then

    echo "Missing:"
    echo "${RUN_DIR}"

    exit 1

fi



# ============================================================
# Extract APK files
# ============================================================


for PACKAGE in ${CUSTOM_PACKAGES}

do


echo
echo "=========================================="
echo "Process:"
echo "${PACKAGE}"
echo "=========================================="


RUN_FILE=$(find "${RUN_DIR}" \
    -maxdepth 1 \
    -name "*${PACKAGE}*.run" \
    | head -n1)



if [ -z "${RUN_FILE}" ]; then

    echo "Run file missing:"
    echo "${PACKAGE}"

    exit 1

fi



WORK="/tmp/${PACKAGE}"

rm -rf "${WORK}"

mkdir -p "${WORK}"



echo "Extract run:"
echo "${RUN_FILE}"


sh "${RUN_FILE}" \
    --target "${WORK}" \
    --noexec \
    --nochown



echo "Copy apk files"


find "${WORK}" \
    -type f \
    -name "*.apk" \
    -exec cp -v {} "${PACKAGE_ROOT}/" \;



done



echo
echo "=========================================="
echo "Third-party APK repository"
echo "=========================================="


ls -lah "${PACKAGE_ROOT}"


echo "Completed"
