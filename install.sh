#!/system/bin/sh
# 兼容入口：部分管理器调用 install.sh 而非 customize.sh
MODPATH=${1:-${0%/*}}
sh "$MODPATH/customize.sh" "$MODPATH"
exit 0