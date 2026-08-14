# ct_intercept — Container Interception Layer

**通用容器中间层 KernelSU 模块 v2.6**

纯本地进程交互，不暴露外部端口。提供 `ct` 命令行工具和 `exec_code` 大段代码安全传递机制。

---

## 架构

```
┌──────────────────────────────┐
│     Operit / droidspaces     │
│         exec_code            │
└──────────┬───────────────────┘
           │ ct exec_code @b64:<base64>
┌──────────▼───────────────────┐
│     ct (shell script)        │
│  /data/adb/modules/          │
│  ct_intercept/system/bin/ct  │
└──────────┬───────────────────┘
           │ nc 127.0.0.1:<daemon_port>
┌──────────▼───────────────────┐
│  ct_receiver_daemon.py       │
│  容器内常驻守护进程           │
│  每容器独立端口 (9998起)     │
│  base64 → 解码 → sh 执行     │
└──────────────────────────────┘
```

---

## 文件结构

```
ct_intercept/
├── module.prop                    # KernelSU 模块元数据
├── customize.sh                   # 安装时：备份配置 + 立即扫描部署
├── install.sh                     # 兼容入口（部分管理器调用 install.sh）
├── uninstall.sh                   # 卸载时：清理容器 daemon + 备份配置
├── service.sh                     # 开机：扫描容器 → 自动分配端口 → 部署 daemon
└── system/
    └── bin/
        ├── ct                     # 主命令（shell 脚本）
        └── ct_socket_transfer.py  # 常驻守护进程（Python 3，argv 端口参数）
```

---

## 核心组件

### ct — 容器中间层命令

```bash
# 列出所有容器
ct list

# 进入容器交互终端
ct <容器名> enter

# 执行单条命令
ct <容器名> exec "ls -la"

# 执行大段代码（@b64: 直通模式）
ct <容器名> exec_code @b64:<base64编码的代码>

# 执行大段代码（行内模式）
ct <容器名> exec_code echo