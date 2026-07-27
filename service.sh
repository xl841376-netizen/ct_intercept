#!/system/bin/sh
# ct_intercept 开机自检：扫描容器 → 更新配置 → 部署常驻 daemon

CONFIG_FILE="/data/local/ct/containers.conf"
DAEMON_SRC="/data/adb/modules/ct_intercept/system/bin/ct_socket_transfer.py"

DROIDSPACES=""
for p in /data/local/Droidspaces/bin/droidspaces /system/bin/droidspaces /vendor/bin/droidspaces; do
    [ -x "$p" ] && { DROIDSPACES="$p"; break; }
done

[ -z "$DROIDSPACES" ] && exit 0

OUTPUT=$(su -c "$DROIDSPACES show 2>/dev/null" 2>/dev/null)
NAMES=$(echo "$OUTPUT" | grep '│' | sed 's/│/\n/g' | sed '/^[[:space:]]*$/d' | sed -n '1~2p' | grep -vx 'NAME' | grep -vx 'PID' | grep -v '^─*$' | head -20)

[ -z "$NAMES" ] && exit 0

mkdir -p /data/local/ct 2>/dev/null
> "$CONFIG_FILE"
for name in $NAMES; do
    name=$(echo "$name" | xargs)
    [ -z "$name" ] && continue
    printf "[%s]\ntype=droidspaces\nbinary=%s\ndefault_shell=bash\n\n" "$name" "$DROIDSPACES" >> "$CONFIG_FILE"

    # --- 部署常驻 daemon 到容器 ---
    if [ -f "$DAEMON_SRC" ]; then
        # 推 daemon 脚本
        "$DROIDSPACES" --name="$name" run sh -c "
            cat > /usr/local/bin/ct_receiver_daemon.py
            chmod 0755 /usr/local/bin/ct_receiver_daemon.py
        " < "$DAEMON_SRC" 2>/dev/null

        # 创建 systemd 服务（如果容器有 systemd）
        "$DROIDSPACES" --name="$name" run sh -c "
            if command -v systemctl >/dev/null 2>&1; then
                cat > /etc/systemd/system/ct-receiver.service << 'SVC'
[Unit]
Description=CT Code Receiver Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ct_receiver_daemon.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
SVC
                systemctl daemon-reload 2>/dev/null
                systemctl enable ct-receiver 2>/dev/null
                systemctl restart ct-receiver 2>/dev/null
            fi
        " 2>/dev/null &
    fi
done

exit 0
