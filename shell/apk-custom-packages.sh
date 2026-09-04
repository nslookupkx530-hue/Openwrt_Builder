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


CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"


if [ -z "${CUSTOM_PACKAGES// }" ]; then

    echo "ℹ️ No third-party APK enabled"

    exit 0

fi


echo "CUSTOM_PACKAGES:"
echo "${CUSTOM_PACKAGES}"



# ============================================================
# Detect architecture
# ============================================================


if grep -q '^CONFIG_TARGET_x86_64=y$' "${SOURCE_DIR}/.config"; then

    ARCH="x86"

elif grep -q '^CONFIG_TARGET_x86=y$' "${SOURCE_DIR}/.config"; then

    ARCH="x86"

elif grep -q '^CONFIG_CPU_TYPE_cortex-a53=y$' "${SOURCE_DIR}/.config"; then

    ARCH="arm64-a53"

elif grep -q '^CONFIG_TARGET_arm64=y$' "${SOURCE_DIR}/.config"; then

    ARCH="arm64"

else

    echo "Unsupported architecture"

    exit 1

fi


echo "Selected architecture:"
echo "${ARCH}"



# ============================================================
# Prepare directory
# ============================================================


rm -rf "${BASE_DIR}"
rm -rf "${PACKAGE_DIR}"


mkdir -p \
    "${BASE_DIR}" \
    "${TEMP_DIR}" \
    "${PACKAGE_DIR}"



# ============================================================
# Clone repository
# ============================================================


rm -rf "${APK_REPO_DIR}"


echo "🔄 Clone third-party repository"


git clone \
    --depth=1 \
    "${APK_REPO}" \
    "${APK_REPO_DIR}"



RUN_DIR="${APK_REPO_DIR}/run/${ARCH}"


if [ ! -d "${RUN_DIR}" ]; then

    echo "Missing:"
    echo "${RUN_DIR}"

    exit 1

fi



echo "Repository:"
echo "${RUN_DIR}"



# ============================================================
# Match enabled packages
# ============================================================


for PACKAGE in ${CUSTOM_PACKAGES}

do

    echo
    echo "Search package:"
    echo "${PACKAGE}"


    FOUND=0


    for FILE in "${RUN_DIR}"/*.run

    do

        [ -e "${FILE}" ] || continue


        NAME=$(basename "${FILE}")


        if [[ "${NAME}" == *"${PACKAGE}"* ]]; then


            echo "✅ Selected:"
            echo "${NAME}"


            cp -v \
                "${FILE}" \
                "${BASE_DIR}/"


            FOUND=1


        fi


    done



    if [ "${FOUND}" -eq 0 ]; then


        echo "❌ Cannot find RUN package:"
        echo "${PACKAGE}"


        exit 1


    fi


done



# ============================================================
# Extract RUN
# ============================================================


for RUN_FILE in "${BASE_DIR}"/*.run

do

    [ -e "${RUN_FILE}" ] || continue


    echo
    echo "🧩 Extract:"
    echo "${RUN_FILE}"


    sh "${RUN_FILE}" \
        --target "${TEMP_DIR}" \
        --noexec \
        --nochown


done



# ============================================================
# Collect APK
# ============================================================


echo
echo "📦 Collect APK"



find "${TEMP_DIR}" \
    -type f \
    -name "*.apk" \
    -exec cp -v {} "${PACKAGE_DIR}/" \;



# ============================================================
# Show result
# ============================================================


APK_COUNT=$(find "${PACKAGE_DIR}" \
    -type f \
    -name "*.apk" \
    | wc -l)



echo
echo "=========================================="
echo "Third-party APK count: ${APK_COUNT}"
echo "=========================================="



if [ "${APK_COUNT}" -eq 0 ]; then

    echo "❌ No APK found"

    exit 1

fi



find "${PACKAGE_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.apk" \
    -printf "%f\n" \
    | sort



echo
echo "✅ Third-party APK preparation completed."
