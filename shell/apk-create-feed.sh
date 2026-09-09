#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"


PACKAGE_DIR="${SOURCE_DIR}/packages"


echo "=========================================="
echo "Prepare third-party APK repository"
echo "=========================================="


if [ ! -d "${PACKAGE_DIR}" ]; then

    echo "Missing package directory"

    exit 1

fi


echo "Third-party APK packages:"


ls -lah "${PACKAGE_DIR}"


echo

echo "Repository preparation completed"
