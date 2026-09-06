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


if grep -q '^CONFIG_TARGET_x86_64=y' "${SOURCE_DIR}/.config"; then

    ARCH="x86"

elif grep -q '^CONFIG_TARGET_x86=y' "${SOURCE_DIR}/.config"; then

    ARCH="x86"

elif grep -q '^CONFIG_CPU_TYPE_cortex-a53=y' "${SOURCE_DIR}/.config"; then

    ARCH="arm64-a53"

elif grep -q '^CONFIG_TARGET_arm64=y' "${SOURCE_DIR}/.config"; then

    ARCH="arm64"

else

    echo "Unsupported architecture"

    exit 1

fi



echo "Architecture:"
echo "${ARCH}"



# ============================================================
# Prepare apk tool
# ============================================================


APK_TOOL="${SOURCE_DIR}/staging_dir/host/bin/apk"



if [ ! -x "${APK_TOOL}" ]; then

    echo "Build OpenWrt apk host tool"


    make -C "${SOURCE_DIR}" \
        package/system/apk/host/compile \
        V=s


fi



if [ ! -x "${APK_TOOL}" ]; then

    echo "OpenWrt apk tool missing"

    echo "${APK_TOOL}"

    exit 1

fi



echo "APK tool:"
echo "${APK_TOOL}"



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

    echo "Missing:"
    echo "${RUN_DIR}"

    exit 1

fi



mkdir -p "${PACKAGE_ROOT}"



# ============================================================
# Convert packages
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

    echo "RUN package missing:"
    echo "${PACKAGE}"

    exit 1

fi



RUN_WORK="/tmp/${PACKAGE}-run"


ROOT_WORK="/tmp/${PACKAGE}-root"



rm -rf \
    "${RUN_WORK}" \
    "${ROOT_WORK}"


mkdir -p \
    "${RUN_WORK}" \
    "${ROOT_WORK}"



echo "Extract RUN:"
echo "${RUN_FILE}"



sh "${RUN_FILE}" \
    --target "${RUN_WORK}" \
    --noexec \
    --nochown



echo "APK files:"


find "${RUN_WORK}" \
    -name "*.apk" \
    -printf "%f\n"



# ============================================================
# Install APK into rootfs
# ============================================================


for APK_FILE in "${RUN_WORK}"/*.apk

do


    [ -e "${APK_FILE}" ] || continue



    echo

    echo "Install APK:"
    echo "${APK_FILE}"



    "${APK_TOOL}" add \
        --root "${ROOT_WORK}" \
        --initdb \
        --allow-untrusted \
        "${APK_FILE}"



done



# ============================================================
# Generate OpenWrt package
# ============================================================


PKG_DIR="${PACKAGE_ROOT}/${PACKAGE}"



rm -rf "${PKG_DIR}"


mkdir -p "${PKG_DIR}/files"



echo "Copy root filesystem"



cp -a \
    "${ROOT_WORK}"/* \
    "${PKG_DIR}/files/" \
    2>/dev/null || true



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

Third party APK converted package

endef



define Build/Compile

endef



define Package/${PACKAGE}/install

	\$(CP) ./files/* \$(1)/

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
    -name Makefile \
    -print \
    | sort



echo

echo "Completed"
