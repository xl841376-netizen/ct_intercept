#!/bin/sh
# ct_intercept build: package module into a KernelSU-flashable zip
set -e
cd "$(dirname "$0")"
VERSION=$(grep -E "^version=" module.prop | cut -d= -f2)
OUT="ct_intercept-v${VERSION}.zip"
[ -f "$OUT" ] && rm -f "$OUT"
# zip 根目录即模块根：module.prop / *.sh / system/bin/...
zip -qr "$OUT" module.prop customize.sh install.sh uninstall.sh service.sh system
chmod 0755 customize.sh install.sh uninstall.sh service.sh system/bin/ct system/bin/ct_socket_transfer.py
echo "BUILD_OK: $OUT"
unzip -l "$OUT" | head -12
