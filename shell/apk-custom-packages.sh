#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

APK_REPO="https://github.com/wukongdaily/apk.git"

TEMP_DIR="/tmp/wukongdaily-apk"

APK_OUTPUT="${SOURCE_DIR}/packages/third-party"

FILES_DIR="${SOURCE_DIR}/files"


echo "=========================================="
echo " Prepare third-party APK repository"
echo "=========================================="


CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"


if [ -z "${CUSTOM_PACKAGES// }" ]; then

    echo "No third-party APK packages"

    exit 0

fi


echo "Selected packages:"
echo "${CUSTOM_PACKAGES}"



# ==================================================
# Detect architecture
# ==================================================


if grep -q '^CONFIG_TARGET_x86_64=y' "${SOURCE_DIR}/.config"; then

    ARCH="x86"

elif grep -q '^CONFIG_TARGET_x86=y' "${SOURCE_DIR}/.config"; then

    ARCH="x86"

elif grep -q '^CONFIG_TARGET_mediatek=y' "${SOURCE_DIR}/.config"; then

    ARCH="arm64-a53"

elif grep -q '^CONFIG_TARGET_arm64=y' "${SOURCE_DIR}/.config"; then

    ARCH="arm64"

else

    echo "Unsupported architecture"

    exit 1

fi


echo "Architecture:"
echo "${ARCH}"



# ==================================================
# Clone APK repo
# ==================================================


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



mkdir -p "${APK_OUTPUT}"

rm -f "${APK_OUTPUT}"/*.apk



# ==================================================
# Extract run packages
# ==================================================


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

    echo "RUN file missing:"
    echo "${PACKAGE}"

    exit 1

fi



WORK="/tmp/${PACKAGE}"

rm -rf "${WORK}"

mkdir -p "${WORK}"



echo "Extract:"
echo "${RUN_FILE}"


sh "${RUN_FILE}" \
    --target "${WORK}" \
    --noexec \
    --nochown



echo "Collect APK files"


find "${WORK}" \
    -type f \
    -name "*.apk" \
    -exec cp {} "${APK_OUTPUT}/" \;



done



# ==================================================
# Generate APK repository index
# ==================================================


echo
echo "=========================================="
echo "Generate APK index"
echo "=========================================="


cd "${APK_OUTPUT}"


if [ ! -f *.apk ]; then

    echo "No APK generated"

    exit 1

fi



APK_TOOL="${SOURCE_DIR}/staging_dir/host/bin/apk"



if [ ! -x "${APK_TOOL}" ]; then

    echo "apk host tool missing"

    exit 1

fi



"${APK_TOOL}" index \
    -o packages.adb \
    *.apk



echo
echo "Third-party APK repository:"
ls -lah "${APK_OUTPUT}"
