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
# Convert APK to OpenWrt package
# ============================================================


for PACKAGE in ${CUSTOM_PACKAGES}

do

    echo
    echo "=========================================="
    echo "Build package: ${PACKAGE}"
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



    WORK="/tmp/${PACKAGE}"


    rm -rf "${WORK}"

    mkdir -p "${WORK}"



    echo "Extract:"
    echo "${RUN_FILE}"


    sh "${RUN_FILE}" \
        --target "${WORK}" \
        --noexec \
        --nochown



    APK_FILE=$(find "${WORK}" \
        -name "${PACKAGE}-*.apk" \
        | head -n1)



    if [ -z "${APK_FILE}" ]; then

        echo "APK missing for ${PACKAGE}"

        exit 1

    fi



    PKG_DIR="${PACKAGE_ROOT}/${PACKAGE}"


    rm -rf "${PKG_DIR}"

    mkdir -p "${PKG_DIR}/files"



    cp "${APK_FILE}" \
       "${PKG_DIR}/files/"



    cat > "${PKG_DIR}/Makefile" <<EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=${PACKAGE}
PKG_VERSION:=1
PKG_RELEASE:=1

include \$(INCLUDE_DIR)/package.mk


define Package/${PACKAGE}
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=${PACKAGE}
endef


define Package/${PACKAGE}/description
Third party APK package converted from wukongdaily
endef


define Build/Compile
endef


define Package/${PACKAGE}/install

	\$(INSTALL_DIR) \$\$(1)/tmp/packages

	\$(INSTALL_DATA) ./files/*.apk \
		\$\$(1)/tmp/packages/

endef


\$(eval \$(call BuildPackage,${PACKAGE}))
EOF



    echo "Created:"
    echo "${PKG_DIR}"



done



echo
echo "=========================================="
echo "Third-party OpenWrt packages"
echo "=========================================="


find "${PACKAGE_ROOT}" \
    -maxdepth 2 \
    -type f \
    | sort


echo
echo "Completed"
