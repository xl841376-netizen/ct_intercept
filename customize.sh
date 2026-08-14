#!/system/bin/sh
# ct_intercept 安装脚本（KernelSU/Magisk 安装模块时执行，$1=MODPATH）
MODPATH=${1:-${0%/*}}
CT_DIR=/data/local/ct
LOG="$CT_DIR/install.log"
mkdir -p "$CT_DIR" 2>/dev/null
log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

log "=== install start ==="
log "MODPATH=$MODPATH"

# 1. 备份旧配置（保留用户已有容器映射）
if [ -f "$CT_DIR/containers.conf" ]; then
    cp "$CT_DIR/containers.conf" "$CT_DIR/containers.conf.pre-install.bak" 2>/dev/null
    log "backup old containers.conf -> containers.conf.pre-install.bak"
fi

# 2. 探测 droidspaces
DROIDSPACES=""
for p in /data/local/Droidspaces/bin/droidspaces /system/bin/droidspaces /vendor/bin/droidspaces; do
    [ -x "$p" ] && { DROIDSPACES="$p"; break; }
done
if [ -z "$DROIDSPACES" ]; then
    log "droidspaces binary not found; skip initial deploy (service.sh will handle at boot)"
    exit 0
fi
log "droidspaces=$DROIDSPACES"

# 3. 立即执行一次配置扫描 + daemon 部署（容器在运行则立刻生效）
if [ -f "$MODPATH/service.sh" ]; then
    sh "$MODPATH/service.sh" >> "$LOG" 2>&1
    log "initial deploy exit=$?"
else
    log "service.sh missing, skip initial deploy"
fi

log "=== install done ==="
exit 0