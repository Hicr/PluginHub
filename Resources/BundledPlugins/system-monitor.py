#!/usr/bin/env python3
# PluginHub:
#   name: 系统监控
#   description: 显示 CPU、内存、磁盘、网速、电源等系统状态
#   icon: desktopcomputer
# /PluginHub

import json
import subprocess
import os
import time
from datetime import datetime, timezone

TEMP_FILE = "/tmp/pluginhub_net_bytes.json"


def run_cmd(cmd, timeout=5):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return result.stdout
    except Exception:
        return ""


def get_cpu_usage():
    out = run_cmd(["top", "-l", "1", "-n", "0"])
    for line in out.split("\n"):
        if "CPU usage" in line:
            parts = line.split(",")
            try:
                user = float(parts[0].split(":")[-1].strip().replace("%", "").replace(" user", ""))
                sys_pct = float(parts[1].strip().replace("%", "").replace(" sys", ""))
                return round(user + sys_pct, 1)
            except (ValueError, IndexError):
                pass
    return None


def get_memory_usage():
    out = run_cmd(["vm_stat"])
    active = wired = free = inactive = 0
    for line in out.split("\n"):
        if "Pages active" in line:
            active = int(line.split(":")[-1].strip().rstrip("."))
        elif "Pages wired" in line:
            wired = int(line.split(":")[-1].strip().rstrip("."))
        elif "Pages free" in line:
            free = int(line.split(":")[-1].strip().rstrip("."))
        elif "Pages inactive" in line:
            inactive = int(line.split(":")[-1].strip().rstrip("."))
    total = active + wired + free + inactive
    if total > 0:
        return round((active + wired) / total * 100, 1)
    return None


def get_disk_info():
    out = run_cmd(["df", "-H", "/"])
    for line in out.split("\n"):
        parts = line.split()
        if len(parts) >= 9 and parts[0].startswith("/dev/"):
            pct = int(parts[4].replace("%", "")) if parts[4].endswith("%") else 0
            # 容量用 GiB (/1024) 显示
            try:
                total_blocks = int(parts[1].replace("Gi", "").replace("G", "")) if any(c.isdigit() for c in parts[1]) else 0
                avail_blocks = int(parts[3].replace("Gi", "").replace("G", "")) if any(c.isdigit() for c in parts[3]) else 0
            except ValueError:
                total_blocks = 0
                avail_blocks = 0
            return pct, avail_blocks, total_blocks
    return None, None, None


def get_network_speed():
    out = run_cmd(["netstat", "-ib"])
    rx_total = tx_total = 0
    for line in out.split("\n"):
        parts = line.split()
        if len(parts) >= 10:
            if parts[0] in ("lo0", "Name", "anpi"):
                continue
            try:
                rx_total += int(parts[6])
                tx_total += int(parts[9])
            except ValueError:
                continue
    if rx_total == 0:
        return None, None

    prev = {}
    if os.path.exists(TEMP_FILE):
        try:
            with open(TEMP_FILE) as f:
                prev = json.load(f)
        except Exception:
            pass

    now = time.time()
    down = up = None
    if prev.get("rx") is not None and prev.get("ts"):
        elapsed = now - prev["ts"]
        if elapsed > 0:
            down = int((rx_total - prev["rx"]) / elapsed)
            up = int((tx_total - prev["tx"]) / elapsed)

    try:
        with open(TEMP_FILE, "w") as f:
            json.dump({"rx": rx_total, "tx": tx_total, "ts": now}, f)
    except Exception:
        pass
    return down, up


def fmt_speed(b):
    if b is None:
        return "--"
    mb = b / 1024 / 1024
    if mb >= 1:
        return f"{mb:.1f} MB/s"
    return f"{b / 1024:.1f} KB/s"


def get_power_info():
    batt_out = run_cmd(["pmset", "-g", "batt"])
    on_ac = "AC Power" in batt_out
    wattage = None
    if on_ac:
        ac_out = run_cmd(["pmset", "-g", "ac"])
        for line in ac_out.split("\n"):
            if "Wattage" in line:
                try:
                    wattage = int(line.split("=")[-1].strip().replace("W", ""))
                except (ValueError, IndexError):
                    pass
    return on_ac, wattage


def get_thermal_state():
    state = os.environ.get("PLUGINHUB_THERMAL_STATE", "nominal")
    levels = {"nominal": ("正常", "#34C759"), "fair": ("偏高", "#FFD60A"),
              "serious": ("很高", "#FF9500"), "critical": ("严重", "#FF3B30")}
    return levels.get(state, ("正常", "#34C759"))


def usage_color(pct):
    if pct >= 80: return "#FF3B30"
    if pct >= 60: return "#FF9500"
    if pct >= 40: return "#FFD60A"
    return "#34C759"


# --- 收集数据 ---
cpu = get_cpu_usage()
memory = get_memory_usage()
disk_pct, disk_avail, disk_total = get_disk_info()
speed_down, speed_up = get_network_speed()
on_ac, power_w = get_power_info()
thermal_label, thermal_color = get_thermal_state()

# --- 构建组件 ---
components = []

# ===== 核心指标区（3 列：CPU | 内存 | 磁盘）=====

# CPU 进度条
if cpu is not None:
    components.append({
        "type": "progress",
        "data": {
            "id": "cpu",
            "label": "CPU",
            "value": cpu,
            "max": 100,
            "unit": "%",
            "color": usage_color(cpu),
            "style": "bar"
        }
    })

# 内存 进度条
if memory is not None:
    components.append({
        "type": "progress",
        "data": {
            "id": "memory",
            "label": "内存",
            "value": memory,
            "max": 100,
            "unit": "%",
            "color": usage_color(memory),
            "style": "bar"
        }
    })

# 磁盘 进度条 + 容量信息
if disk_pct is not None and disk_avail and disk_total:
    components.append({
        "type": "progress",
        "data": {
            "id": "disk",
            "label": "磁盘",
            "value": disk_pct,
            "max": 100,
            "unit": f"{disk_avail}G / {disk_total}G",
            "color": usage_color(disk_pct),
            "style": "bar"
        }
    })

# ===== 状态信息区（3 列：电源 | 网速 | 热状态）=====

# 电源
if on_ac:
    power_text = f"⚡ {power_w}W 充电中" if power_w else "⚡ 电源供电"
else:
    power_text = "🔋 电池供电"
components.append({
    "type": "text",
    "data": {
        "id": "power",
        "content": power_text,
        "style": "plain"
    }
})

# 网速
net_text = f"↓ {fmt_speed(speed_down)}\n↑ {fmt_speed(speed_up)}"
components.append({
    "type": "text",
    "data": {
        "id": "network",
        "content": net_text,
        "style": "plain",
        "icon": "network"
    }
})

# 热状态
components.append({
    "type": "text",
    "data": {
        "id": "thermal",
        "content": thermal_label,
        "style": "plain",
        "icon": "thermometer.medium"
    }
})

data = {
    "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "title": "系统监控",
    "icon": "desktopcomputer",
    "components": components,
}

print(json.dumps(data, ensure_ascii=False))
