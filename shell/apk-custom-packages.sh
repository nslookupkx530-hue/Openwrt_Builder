#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"

PACKAGE_ROOT="${SOURCE_DIR}/package/third-party"

TEMP_DIR="/tmp/wukongdaily-apk"

APK_REPO="https://github.com/wukongdaily/apk.git"



echo "=========================================="
echo " Prepare third-party OpenWrt packages"
echo "=========================================="


CUSTOM_PACKAGES="${CUSTOM_PACKAGES:-}"



if [ -z "${CUSTOM_PACKAGES// }" ]; then

    echo "No third-party packages enabled"

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



echo "Architecture:"
echo "${ARCH}"



# ============================================================
# Clone APK repository
# ============================================================


rm -rf "${TEMP_DIR}"


git clone \
    --depth=1 \
    "${APK_REPO}" \
    "${TEMP_DIR}"



RUN_DIR="${TEMP_DIR}/run/${ARCH}"



if [ ! -d "${RUN_DIR}" ]; then

    echo "Missing APK directory:"
    echo "${RUN_DIR}"

    exit 1

fi



mkdir -p "${PACKAGE_ROOT}"



# ============================================================
# Convert RUN package
# ============================================================


for PACKAGE in ${CUSTOM_PACKAGES}

do


    echo
    echo "=========================================="
    echo "Process package: ${PACKAGE}"
    echo "=========================================="


    RUN_FILE=$(find "${RUN_DIR}" \
        -maxdepth 1 \
        -name "*${PACKAGE}*.run" \
        | head -n1)



    if [ -z "${RUN_FILE}" ]; then

        echo "Cannot find:"
        echo "${PACKAGE}"

        exit 1

    fi



    RUN_WORK="/tmp/${PACKAGE}"



    rm -rf "${RUN_WORK}"

    mkdir -p "${RUN_WORK}"



    echo "Extract RUN:"
    echo "${RUN_FILE}"



    sh "${RUN_FILE}" \
        --target "${RUN_WORK}" \
        --noexec \
        --nochown



    echo
    echo "APK list:"



    find "${RUN_WORK}" \
        -maxdepth 1 \
        -name "*.apk" \
        -printf "%f\n" \
        | sort



    # ========================================================
    # Convert every APK
    # ========================================================


    for APK_FILE in "${RUN_WORK}"/*.apk

    do


        [ -e "${APK_FILE}" ] || continue



        APK_NAME=$(basename "${APK_FILE}")



        PKG_NAME=$(echo "${APK_NAME}" \
            | sed -E 's/-[0-9].*\.apk$//')



        echo
        echo "------------------------------------------"
        echo "Convert APK:"
        echo "${APK_NAME}"
        echo "Package:"
        echo "${PKG_NAME}"
        echo "------------------------------------------"



        PKG_DIR="${PACKAGE_ROOT}/${PKG_NAME}"



        rm -rf "${PKG_DIR}"

        mkdir -p "${PKG_DIR}/files"



        APK_TMP="/tmp/${PKG_NAME}-apk"

        APK_WORK="/tmp/${PKG_NAME}-root"



        rm -rf "${APK_TMP}"
        rm -rf "${APK_WORK}"



        mkdir -p "${APK_TMP}"
        mkdir -p "${APK_WORK}"



        echo "Extract APK filesystem"



        echo "Extract APK filesystem"



        rm -rf "${APK_WORK}"
		
		mkdir -p "${APK_WORK}"

        tar -xf "${APK_FILE}" \
            -C "${APK_WORK}"


        echo "Copy filesystem"


        cp -a \
            "${APK_WORK}"/* \
            "${PKG_DIR}/files/" \
            2>/dev/null || true



        # ====================================================
        # Generate OpenWrt package Makefile
        # ====================================================


        cat > "${PKG_DIR}/Makefile" <<EOF
include \$(TOPDIR)/rules.mk


PKG_NAME:=${PKG_NAME}

PKG_VERSION:=1

PKG_RELEASE:=1


include \$(INCLUDE_DIR)/package.mk



define Package/${PKG_NAME}

  SECTION:=utils

  CATEGORY:=Utilities

  TITLE:=${PKG_NAME}

endef



define Package/${PKG_NAME}/description

Third party package converted from APK

endef



define Build/Compile

endef



define Package/${PKG_NAME}/install

	\$(CP) ./files/* \$(1)/

endef



\$(eval \$(call BuildPackage,${PKG_NAME}))
EOF



        echo "Created:"
        echo "${PKG_DIR}"



    done



done



echo
echo "=========================================="
echo "Third-party OpenWrt packages"
echo "=========================================="


find "${PACKAGE_ROOT}" \
    -maxdepth 2 \
    -name Makefile \
    -print \
    | sort



echo
echo "Completed"
