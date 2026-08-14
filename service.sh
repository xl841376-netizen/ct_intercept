#!/system/bin/sh
# ct_intercept 开机自检：扫描容器 → 更新配置（自动分配独立端口）→ 部署常驻 daemon
CONFIG_FILE="/data/local/ct/containers.conf"
DAEMON_SRC="/data/adb/modules/ct_intercept/system/bin/ct_socket_transfer.py"
PORT_BASE=9998

DROIDSPACES=""
for p in /data/local/Droidspaces/bin/droidspaces /system/bin/droidspaces /vendor/bin/droidspaces; do
    [ -x "$p" ] && { DROIDSPACES="$p"; break; }
done
[ -z "$DROIDSPACES" ] && exit 0

OUTPUT=$(su -c "$DROIDSPACES show 2>/dev/null" 2>/dev/null)
NAMES=$(echo "$OUTPUT" | grep '│' | sed 's/│/\n/g' | sed '/^[[:space:]]*$/d' | awk 'NR%2==1 { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); if ($0 != "" && $0 != "NAME" && $0 != "PID") print }' | head -20)
[ -z "$NAMES" ] && exit 0

mkdir -p /data/local/ct 2>/dev/null
> "$CONFIG_FILE"
PORT=$PORT_BASE
for name in $NAMES; do
    name=$(echo "$name" | xargs)
    [ -z "$name" ] && continue
    # 每个容器独立端口，避免 host 网络下端口冲突导致串容器
    printf "[%s]\ntype=droidspaces\nbinary=%s\ndefault_shell=bash\ndaemon_port=%s\n\n" "$name" "$DROIDSPACES" "$PORT" >> "$CONFIG_FILE"

    if [ -f "$DAEMON_SRC" ]; then
        # base64 传递 daemon 内容（droidspaces run 不转发 stdin，必须走 argv）
        DAEMON_B64=$(base64 "$DAEMON_SRC" | tr -d '\n')
        "$DROIDSPACES" --name="$name" run sh -c "echo '$DAEMON_B64' | base64 -d > /usr/local/bin/ct_receiver_daemon.py.tmp && mv /usr/local/bin/ct_receiver_daemon.py.tmp /usr/local/bin/ct_receiver_daemon.py && chmod 0755 /usr/local/bin/ct_receiver_daemon.py && wc -c /usr/local/bin/ct_receiver_daemon.py" 2>/dev/null

        # systemd 常驻服务（printf 单行生成 unit，端口参数传入）
        "$DROIDSPACES" --name="$name" run sh -c "printf '%s\n' '[Unit]' 'Description=CT Code Receiver Daemon' 'After=network.target' '[Service]' 'Type=simple' 'ExecStart=/usr/bin/python3 /usr/local/bin/ct_receiver_daemon.py $PORT' 'Restart=always' 'RestartSec=2' '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/ct-receiver.service && systemctl daemon-reload && systemctl enable ct-receiver 2>/dev/null && systemctl restart ct-receiver" 2>/dev/null &
    fi
    PORT=$((PORT + 1))
done

exit 0