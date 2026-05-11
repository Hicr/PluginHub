#!/usr/bin/env python3
# PluginHub:
#   name: 服务器监控
#   description: 通过 SSH 监控远程服务器 CPU、内存、磁盘
#   icon: server.rack
#   parameters:
#     - name: servers
#       type: server_list
#       label: 服务器列表
#       default: "[]"
#     - name: terminal
#       type: choice
#       label: 终端
#       default: 自动
#       options:
#         - label: 自动检测
#           value: 自动
#         - label: Terminal
#           value: Terminal
#         - label: iTerm
#           value: iTerm
#         - label: Ghostty
#           value: Ghostty
#     - name: auto_retry
#       type: boolean
#       label: 断联后自动重试
#       default: "false"
# /PluginHub

import json
import subprocess
import os
import sys
import re
import shutil
from datetime import datetime, timezone

STATE_FILE = "/tmp/pluginhub_server_state.json"


def utc_now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_params(argv):
    values = {}
    i = 0
    while i < len(argv):
        if argv[i] == "--pluginhub-param" and i + 1 < len(argv):
            kv = argv[i + 1]
            if "=" in kv:
                k, v = kv.split("=", 1)
                values[k] = v
            i += 2
        else:
            i += 1
    return values


def ssh_cmd(host, port, user, key, remote_cmd, timeout=8):
    key_path = os.path.expanduser(key)
    args = [
        "ssh", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes", "-p", str(port), "-i", key_path,
        f"{user}@{host}", remote_cmd
    ]
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        if result.returncode != 0:
            return None, result.stderr.strip() or f"exit {result.returncode}"
        return result.stdout.strip(), None
    except subprocess.TimeoutExpired:
        return None, "超时"
    except FileNotFoundError:
        return None, "ssh 不可用"
    except Exception as e:
        return None, str(e)[:60]


def parse_cpu(output):
    for line in output.split("\n"):
        if "Cpu(s)" in line or "CPU" in line:
            nums = re.findall(r'(\d+\.?\d*)', line)
            if nums:
                return float(nums[0])
    return None


def parse_mem(output):
    total = used = None
    for line in output.split("\n"):
        if line.startswith("Mem:"):
            parts = line.split()
            if len(parts) >= 3:
                total = float(parts[1])
                used = float(parts[2])
    if total and total > 0 and used is not None:
        pct = round(used / total * 100, 1)
        free = total - used
        if total >= 1024:
            info = f"{free/1024:.1f}G / {total/1024:.1f}G"
        else:
            info = f"{free:.0f}M / {total:.0f}M"
        return pct, info
    return None, None


def parse_disk(output):
    for line in output.split("\n"):
        parts = line.split()
        if len(parts) >= 5 and parts[-1] == "/":
            try:
                pct = float(parts[-2].replace("%", ""))
                size = parts[1]
                avail = parts[3]
                return pct, f"{avail} / {size}"
            except (ValueError, IndexError):
                pass
    return None, None


def detect_terminal(preferred):
    """自动检测可用终端"""
    if preferred != "自动":
        # 检查指定终端是否安装
        if preferred == "Terminal":
            return preferred  # Terminal always exists on macOS
        for app in ["iTerm", "Ghostty"]:
            if preferred == app and shutil.which(app.lower()) or os.path.exists(f"/Applications/{app}.app"):
                return preferred
        # 指定终端未安装，回退到 Terminal
        return "Terminal"

    # 自动检测
    if shutil.which("iterm") or os.path.exists("/Applications/iTerm.app"):
        return "iTerm"
    if shutil.which("ghostty") or os.path.exists("/Applications/Ghostty.app"):
        return "Ghostty"
    return "Terminal"


def terminal_cmd(terminal, host, port, user, key):
    key_path = os.path.expanduser(key)
    ssh_str = f"ssh -i {key_path} -p {port} {user}@{host}"
    if terminal == "iTerm":
        return f"osascript -e 'tell app \"iTerm\" to create window with default profile command \"{ssh_str}\"'"
    elif terminal == "Ghostty":
        return f"open -na Ghostty --args -e {ssh_str}"
    else:
        return f"osascript -e 'tell app \"Terminal\" to do script \"{ssh_str}\"'"


def usage_color(pct):
    if pct is None:
        return "#8E8E93"
    if pct >= 90:
        return "#FF3B30"
    if pct >= 70:
        return "#FF9500"
    if pct >= 50:
        return "#FFD60A"
    return "#34C759"


# --- 主逻辑 ---
params = parse_params(sys.argv[1:])
servers_raw = params.get("servers", "[]")
terminal_choice = params.get("terminal", "自动")
auto_retry = params.get("auto_retry", "false").lower() in ("true", "1", "yes")

try:
    servers = json.loads(servers_raw)
except json.JSONDecodeError:
    print(json.dumps({"error": "服务器配置 JSON 格式错误"}))
    sys.exit(1)

terminal = detect_terminal(terminal_choice)

# 加载失败状态
failed_servers = set()
if os.path.exists(STATE_FILE):
    try:
        with open(STATE_FILE) as f:
            failed_servers = set(json.load(f).get("failed", []))
    except Exception:
        pass

components = []
new_failed = []
online_count = 0
total_count = len(servers) if servers else 0

for srv in servers:
    host = srv.get("host", "")
    port = srv.get("port", 22)
    user = srv.get("user", "root")
    key = srv.get("key", "~/.ssh/id_rsa")
    name = srv.get("name", host)
    server_id = f"{user}@{host}:{port}"

    # 之前失败过
    if server_id in failed_servers:
        if auto_retry:
            # 开启自动重试：尝试重连，以正常检测逻辑为准
            pass
        else:
            # 未开启自动重试：跳过自动检测，等待手动测试连接
            components.append({
                "type": "text",
                "data": {
                    "id": f"err-{host}",
                    "content": f"{name}  连接失败",
                    "style": "alert",
                    "icon": "xmark.circle.fill"
                }
            })
            new_failed.append(server_id)
            key_path = os.path.expanduser(key)
            fix_cmd = (
                f"ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "
                f"-p {port} -i {key_path} {user}@{host} echo ok "
                f"&& python3 -c \"import json; d=json.load(open('{STATE_FILE}')); "
                f"d['failed'].remove('{server_id}'); json.dump(d, open('{STATE_FILE}','w'))\" 2>/dev/null; true"
            )
            components.append({
                "type": "interactive",
                "data": {
                    "id": f"btn-{host}",
                    "type": "button",
                    "config": {
                        "actions": [
                            {"id": "test", "label": "测试连接", "type": "callback", "payload": fix_cmd},
                        ]
                    }
                }
            })
            continue

    # 检测连接（正常检测 / auto_retry 重试）
    test_out, test_err = ssh_cmd(host, port, user, key, "echo ok")

    if test_err:
        new_failed.append(server_id)
        components.append({
            "type": "text",
            "data": {
                "id": f"err-{host}",
                "content": f"{name}  {test_err[:50]}",
                "style": "alert",
                "icon": "xmark.circle.fill"
            }
        })
        key_path = os.path.expanduser(key)
        fix_cmd = (
            f"ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "
            f"-p {port} -i {key_path} {user}@{host} echo ok "
            f"&& rm -f {STATE_FILE}; true"
        )
        components.append({
            "type": "interactive",
            "data": {
                "id": f"btn-{host}",
                "type": "button",
                "config": {
                    "actions": [
                        {"id": "test", "label": "测试连接", "type": "callback", "payload": fix_cmd},
                    ]
                }
            }
        })
        continue

    online_count += 1

    # 采集数据
    cpu_out, _ = ssh_cmd(host, port, user, key,
                         "top -bn1 2>/dev/null | grep -E 'Cpu|CPU'")
    cpu = parse_cpu(cpu_out) if cpu_out else None

    mem_out, _ = ssh_cmd(host, port, user, key, "free -m 2>/dev/null")
    mem_pct, mem_info = parse_mem(mem_out) if mem_out else (None, None)

    disk_out, _ = ssh_cmd(host, port, user, key, "df -h / 2>/dev/null")
    disk_pct, disk_info = parse_disk(disk_out) if disk_out else (None, None)

    # 服务器名称（第一行）
    components.append({
        "type": "text",
        "data": {
            "id": f"label-{host}",
            "content": name,
            "style": "plain",
            "icon": "server.rack"
        }
    })

    # SSH 按钮
    components.append({
        "type": "interactive",
        "data": {
            "id": f"ssh-{host}",
            "type": "button",
            "config": {
                "actions": [
                    {"id": "connect", "label": "SSH", "type": "callback",
                     "payload": terminal_cmd(terminal, host, port, user, key)},
                ]
            }
        }
    })

    if cpu is not None:
        components.append({
            "type": "progress",
            "data": {
                "id": f"cpu-{host}",
                "label": "CPU",
                "value": cpu,
                "max": 100,
                "unit": "%",
                "color": usage_color(cpu),
                "style": "bar"
            }
        })

    if mem_pct is not None:
        components.append({
            "type": "progress",
            "data": {
                "id": f"mem-{host}",
                "label": "内存",
                "value": mem_pct,
                "max": 100,
                "unit": mem_info or "%",
                "color": usage_color(mem_pct),
                "style": "bar"
            }
        })

    if disk_pct is not None:
        components.append({
            "type": "progress",
            "data": {
                "id": f"disk-{host}",
                "label": "磁盘",
                "value": disk_pct,
                "max": 100,
                "unit": disk_info or "%",
                "color": usage_color(disk_pct),
                "style": "bar"
            }
        })

# 保存失败列表
if new_failed:
    try:
        with open(STATE_FILE, "w") as f:
            json.dump({"failed": new_failed}, f)
    except Exception:
        pass
elif os.path.exists(STATE_FILE):
    try:
        os.remove(STATE_FILE)
    except Exception:
        pass

badge = f"{online_count}/{total_count}" if total_count > 0 else None

print(json.dumps({
    "updatedAt": utc_now(),
    "title": "服务器监控",
    "icon": "server.rack",
    "badge": badge,
    "components": components,
}, ensure_ascii=False))
