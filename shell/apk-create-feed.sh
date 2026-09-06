#!/bin/bash


set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"


PKG_DIR="${SOURCE_DIR}/packages"


if [ ! -d "${PKG_DIR}" ]; then

    exit 0

fi


echo "Create APK repository"


mkdir -p \
    "${SOURCE_DIR}/files/etc/apk/keys"



mkdir -p \
    "${SOURCE_DIR}/files/etc/apk/repositories.d"



cp \
    ${PKG_DIR}/*.apk \
    "${SOURCE_DIR}/files/"


echo "local /files" \
> "${SOURCE_DIR}/files/etc/apk/repositories.d/third-party.list"
