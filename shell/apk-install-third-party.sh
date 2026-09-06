#!/bin/bash

set -euo pipefail


SOURCE_DIR="${SOURCE_DIR:-$(pwd)}"


FILES_DIR="${SOURCE_DIR}/files"


APK_DIR="/usr/share/third-party"



mkdir -p \
"${FILES_DIR}/etc/apk/repositories.d" \
"${FILES_DIR}/etc/uci-defaults"



cat > \
"${FILES_DIR}/etc/apk/repositories.d/third-party.list" <<EOF

file://${APK_DIR}

EOF



cat > \
"${FILES_DIR}/etc/uci-defaults/99-install-third-party" <<EOF

#!/bin/sh


apk update


for pkg in ${CUSTOM_PACKAGES}
do

    apk add "\$pkg"

done


exit 0

EOF



chmod +x \
"${FILES_DIR}/etc/uci-defaults/99-install-third-party"
