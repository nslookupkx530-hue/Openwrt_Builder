#!/bin/sh

APK_DIR="/usr/share/third-party"
LOG_FILE="/tmp/third-party-apk-install.log"
DONE_FILE="/etc/third-party-apk-installed"
LOCK_DIR="/tmp/third-party-apk-install.lock"

exec >> "$LOG_FILE" 2>&1

echo
echo "=========================================="
echo "Third-party APK installation started"
date
echo "=========================================="

# 已经安装过则直接退出
if [ -f "$DONE_FILE" ]; then
    echo "Third-party APK packages are already installed."
    exit 0
fi

# 使用 mkdir 实现简单锁，避免并发执行
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "Another third-party APK installation process is running."
    exit 0
fi

# 无论脚本如何退出，都尝试清理锁目录
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

if [ ! -d "$APK_DIR" ]; then
    echo "ERROR: Missing APK directory: $APK_DIR"
    exit 1
fi

set -- "$APK_DIR"/*.apk

if [ ! -f "$1" ]; then
    echo "ERROR: No APK packages found in $APK_DIR"
    exit 1
fi

echo "APK packages to install:"
for apk_file in "$@"; do
    echo "  $apk_file"
done

echo
echo "Waiting for network and DNS..."

MAX_RETRIES=30
COUNT=0

while :; do
    # 优先测试实际 OpenWrt 软件源的 HTTPS 连接。
    # 如果系统没有 wget，则退回到 ping 测试。
    if command -v wget >/dev/null 2>&1; then
        if wget -q -T 8 -O /dev/null \
            "https://downloads.openwrt.org/" 2>/dev/null; then
            break
        fi
    elif command -v uclient-fetch >/dev/null 2>&1; then
        if uclient-fetch -q -T 8 -O /dev/null \
            "https://downloads.openwrt.org/" 2>/dev/null; then
            break
        fi
    elif ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        break
    fi

    if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
        echo "ERROR: Network is not ready after 5 minutes."
        echo "Please inspect: $LOG_FILE"
        exit 1
    fi

    COUNT=$((COUNT + 1))
    echo "Network not ready, retrying in 10 seconds..."
    echo "Attempt: $COUNT/$MAX_RETRIES"
    sleep 10
done

echo
echo "Network is ready."
echo "Checking APK repositories..."

# 更新本地索引，但不执行 apk upgrade
if ! apk update; then
    echo "ERROR: apk update failed."
    exit 1
fi

echo
echo "Installing third-party APK packages..."

# 不默认使用 --force-reinstall，避免重复覆盖已安装包
if ! apk add --allow-untrusted "$@"; then
    echo "ERROR: APK installation failed."
    echo "Possible causes:"
    echo "  - Missing dependencies"
    echo "  - Repository unavailable"
    echo "  - Architecture mismatch"
    echo "  - Package version conflict"
    exit 1
fi

echo
echo "Refreshing LuCI cache..."

rm -f /tmp/luci-indexcache.*
rm -rf /tmp/luci-modulecache

if [ -x /etc/init.d/rpcd ]; then
    /etc/init.d/rpcd restart
fi

if [ -x /etc/init.d/uhttpd ]; then
    /etc/init.d/uhttpd restart
fi

# 只有全部安装和刷新操作成功后才写入完成标志
date > "$DONE_FILE"

echo
echo "=========================================="
echo "Third-party APK installation completed"
date
echo "=========================================="

exit 0
