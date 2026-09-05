#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"


BASE_DIR="${SOURCE_DIR}/extra-packages"

TEMP_DIR="${BASE_DIR}/temp-unpack"


THIRD_PACKAGE_DIR="${SOURCE_DIR}/package/third-party"


APK_REPO="https://github.com/wukongdaily/apk.git"

APK_REPO_DIR="/tmp/wukongdaily-apk"



echo "=========================================="

echo " Prepare third-party OpenWrt packages "

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



echo "Selected architecture:"

echo "${ARCH}"





# ============================================================
# Prepare directory
# ============================================================


rm -rf "${BASE_DIR}"

rm -rf "${THIRD_PACKAGE_DIR}"


mkdir -p \
    "${TEMP_DIR}" \
    "${THIRD_PACKAGE_DIR}"





# ============================================================
# Clone repository
# ============================================================


rm -rf "${APK_REPO_DIR}"


echo "Clone third-party repository"


git clone \
    --depth=1 \
    "${APK_REPO}" \
    "${APK_REPO_DIR}"



RUN_DIR="${APK_REPO_DIR}/run/${ARCH}"



if [ ! -d "${RUN_DIR}" ]; then

    echo "Missing directory:"
    echo "${RUN_DIR}"

    exit 1

fi





# ============================================================
# Download RUN packages
# ============================================================


for PACKAGE in ${CUSTOM_PACKAGES}

do

    FOUND=0


    echo

    echo "Search package: ${PACKAGE}"



    for FILE in "${RUN_DIR}"/*.run

    do

        [ -e "${FILE}" ] || continue



        NAME=$(basename "${FILE}")



        if [[ "${NAME}" == *"${PACKAGE}"* ]]; then


            echo "Selected:"
            echo "${NAME}"



            sh "${FILE}" \
                --target "${TEMP_DIR}" \
                --noexec \
                --nochown



            FOUND=1


            break


        fi


    done



    if [ "${FOUND}" -eq 0 ]; then

        echo "Package not found: ${PACKAGE}"

        exit 1

    fi


done





# ============================================================
# Convert APK to OpenWrt package
# ============================================================


echo

echo "Convert APK to OpenWrt package"





for APK in "${TEMP_DIR}"/*.apk

do

    [ -e "${APK}" ] || continue



    NAME=$(basename "${APK}" .apk)



    PKG_DIR="${THIRD_PACKAGE_DIR}/${NAME}"



    mkdir -p "${PKG_DIR}"



    echo "Generate package: ${NAME}"



    cat > "${PKG_DIR}/Makefile" <<EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=${NAME}
PKG_VERSION:=1.0
PKG_RELEASE:=1

include \$(INCLUDE_DIR)/package.mk


define Package/${NAME}
 SECTION:=utils
 CATEGORY:=Utilities
 TITLE:=${NAME}
 DEPENDS:=+apk
endef


define Package/${NAME}/install

	\$(INSTALL_DIR) \$\$(1)/usr/lib/apk/packages

	\$(INSTALL_DATA) ${NAME}.apk \$\$(1)/usr/lib/apk/packages/

endef


\$(eval \$(call BuildPackage,${NAME}))
EOF



    cp "${APK}" \
       "${PKG_DIR}/${NAME}.apk"



done





echo

echo "=========================================="

echo "Third-party OpenWrt packages"

echo "=========================================="


find "${THIRD_PACKAGE_DIR}" \
-type f \
| sort



echo

echo "Third-party package preparation completed"
