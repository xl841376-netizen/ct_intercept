# ct_intercept — Container Interception Layer

**通用容器中间层 KernelSU 模块 v2.5**

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
           │ nc 127.0.0.1:9998
┌──────────▼───────────────────┐
│  ct_receiver_daemon.py       │
│  容器内常驻守护进程           │
│  监听 127.0.0.1:9998         │
│  base64 → 解码 → sh 执行     │
└──────────────────────────────┘
```

---

## 文件结构

```
ct_intercept/
├── module.prop                    # KernelSU 模块元数据
├── service.sh                     # 开机自检：扫描容器 → 更新配置 → 部署 daemon
├── system/
│   └── bin/
│       ├── ct                     # 主命令（shell 脚本，214 行）
│       └── ct_socket_transfer.py  # 常驻守护进程（Python 3）
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
ct <容器名> exec_code 'echo hello' bash

# 停止容器
ct <容器名> stop

# 查看状态
ct <容器名> status
```

### exec_code 数据流

```
JS 端 base64 编码
  ↓ @b64: 前缀直通，跳过所有 shell 转义
ct shell 脚本识别 @b64: 前缀
  ↓ nc 127.0.0.1:9998 (纯本地 TCP)
ct_receiver_daemon.py 接收
  ↓ base64 → 解码 → 写 /tmp/ct_exec/code_*.sh
sh 执行 → 捕获 stdout/stderr
  ↓ TCP 回传结果
ct → su → droidspaces → 返回 Operit
```

**关键设计：**
- `@b64:` 前缀确保 base64 数据被原样传递，不被 shell 二次解析
- `nc` 直连容器 127.0.0.1:9998（host 网络模式）
- daemon 常驻运行，免去每次传脚本的开销

---

## ct_receiver_daemon.py

常驻代码接收守护进程，监听 `127.0.0.1:9998`：

1. 接收 TCP 连接
2. 读取 base64 编码的代码
3. 解码并写入 `/tmp/ct_exec/code_<timestamp>.sh`
4. `subprocess.run(['sh', script])` 执行
5. 返回 stdout + stderr + exit code
6. 清理临时文件

**部署方式：** `service.sh` 开机自动推送到每个容器的 `/usr/local/bin/ct_receiver_daemon.py`，并通过 systemd 服务 `ct-receiver.service` 自动启动。

---

## service.sh 开机流程

1. 检测 droidspaces 二进制位置
2. `droidspaces show` 扫描所有运行中容器
3. 生成 `/data/local/ct/containers.conf`（INI 格式）
4. 对每个容器：
   - 推送 `ct_receiver_daemon.py` 到 `/usr/local/bin/`
   - 创建 systemd 服务 `ct-receiver.service`（Restart=always）
   - 启动 daemon

---

## containers.conf 格式

```ini
[deb]
type=droidspaces
binary=/data/local/Droidspaces/bin/droidspaces
default_shell=bash

[fuwuronqi]
type=droidspaces
binary=/data/local/Droidspaces/bin/droidspaces
default_shell=bash
```

支持 `droidspaces` 和 `proot` 两种容器类型。

---

## 安装

1. 将此模块放入 `/data/adb/modules/ct_intercept/`
2. 在 KernelSU Manager 中启用模块
3. 重启设备
4. `service.sh` 自动执行，扫描容器并部署 daemon

---

## 与 droidspaces_tools 的配合

[droidspaces_tools](https://github.com/xl841376-netizen/droidspaces_tools) 的 `exec_code` 工具依赖本模块：

```
droidspaces_tools:exec_code("deb", "#!/bin/bash\necho hello") 
  → base64Encode → @b64: 直通 → ct exec_code → daemon → 执行
```

---

## 许可证

MIT License

---

## 作者

Operit — [xl841376-netizen](https://github.com/xl841376-netizen)
