#!/system/bin/sh
# ct_intercept 卸载脚本（KernelSU/Magisk 卸载模块时执行，$1=MODPATH）
# 清理容器内部署的 daemon 与 systemd 服务，备份并移除容器配置
MODPATH=${1:-${0%/*}}
CT_DIR=/data/local/ct
LOG="$CT_DIR/uninstall.log"
mkdir -p "$CT_DIR" 2>/dev/null
log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

log "=== uninstall start ==="
log "MODPATH=$MODPATH"

DROIDSPACES=""
for p in /data/local/Droidspaces/bin/droidspaces /system/bin/droidspaces /vendor/bin/droidspaces; do
    [ -x "$p" ] && { DROIDSPACES="$p"; break; }
done

CONFIG_FILE="$CT_DIR/containers.conf"

# 1. 清理各容器内部署的 daemon 与 systemd 服务
if [ -f "$CONFIG_FILE" ] && [ -n "$DROIDSPACES" ]; then
    NAMES=$(awk -F'[][]' '/^\[.*\]/ { print $2 }' "$CONFIG_FILE" 2>/dev/null)
    for name in $NAMES; do
        [ -z "$name" ] && continue
        log "cleanup container: $name"
        "$DROIDSPACES" --name="$name" run sh -c '
            systemctl disable ct-receiver 2>/dev/null
            systemctl stop ct-receiver 2>/dev/null
            rm -f /etc/systemd/system/ct-receiver.service
            rm -f /usr/local/bin/ct_receiver_daemon.py
            rm -f /usr/local/bin/ct_receiver_daemon.py.tmp
        ' 2>/dev/null
    done
    log "container cleanup done"
else
    log "no containers.conf or droidspaces binary, skip container cleanup"
fi

# 2. 备份并移除配置（模块卸载后 ct 不再识别容器）
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CT_DIR/containers.conf.uninstall.bak" 2>/dev/null
    rm -f "$CONFIG_FILE"
    log "backup + remove containers.conf"
fi

# 3. 清理宿主临时文件
rm -f /data/local/tmp/.ct_*.sh 2>/dev/null
log "host temp files cleaned"

log "=== uninstall done ==="
exit 0