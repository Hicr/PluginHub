#!/usr/bin/env python3
# PluginHub:
#   name: 系统监控
#   description: CPU、内存、电源、磁盘、网速、热状态
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


def get_power_info():
    """返回 (充电中, 功率瓦数)"""
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
    else:
        try:
            result = subprocess.run(
                ["ioreg", "-r", "-c", "AppleSmartBattery"],
                capture_output=True, text=True, timeout=5
            )
            raw_current = raw_voltage = None
            for line in result.stdout.split("\n"):
                if '"InstantAmperage"' in line:
                    try:
                        raw_current = int(line.split("=")[-1].strip())
                    except ValueError:
                        pass
                if '"Voltage"' in line:
                    try:
                        raw_voltage = int(line.split("=")[-1].strip())
                    except ValueError:
                        pass
            if raw_current and raw_voltage:
                # 转换无符号溢出值（负电流 = 放电）
                if raw_current > 0x7FFFFFFFFFFFFFFF:
                    raw_current = raw_current - 0x10000000000000000
                if raw_voltage > 0x7FFFFFFFFFFFFFFF:
                    raw_voltage = raw_voltage - 0x10000000000000000
                wattage = abs(raw_current * raw_voltage) // 1000000
        except Exception:
            pass

    return on_ac, wattage


def get_disk_info():
    out = run_cmd(["df", "-h", "/"])
    for line in out.split("\n"):
        parts = line.split()
        if len(parts) >= 9 and parts[0].startswith("/dev/"):
            return parts[3], parts[1]
    return None


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


def get_thermal_state():
    state = os.environ.get("PLUGINHUB_THERMAL_STATE", "nominal")
    levels = {"nominal": "正常", "fair": "偏高",
              "serious": "很高", "critical": "严重"}
    return levels.get(state, "正常")


def usage_color(pct):
    if pct >= 80:
        return "#FF3B30"
    if pct >= 60:
        return "#FF9500"
    if pct >= 40:
        return "#FFD60A"
    return "#34C759"


# --- 收集数据 ---
cpu = get_cpu_usage()
memory = get_memory_usage()
on_ac, wattage = get_power_info()
disk_info = get_disk_info()
speed_down, speed_up = get_network_speed()
thermal_label = get_thermal_state()

# --- 双列布局 (3x2) ---
components = []

# [1,1] CPU 进度条
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

# [1,2] 内存进度条
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

# [2,1] 电源
if on_ac:
    power_text = f"充电 {wattage}W" if wattage else "电源适配器"
else:
    power_text = f"放电 {wattage}W" if wattage else "电池供电"
components.append({
    "type": "text",
    "data": {
        "id": "power",
        "content": power_text,
        "style": "plain",
        "icon": "powerplug" if on_ac else "battery.100"
    }
})

# [2,2] 磁盘
if disk_info is not None:
    avail, total = disk_info
    components.append({
        "type": "text",
        "data": {
            "id": "disk",
            "content": f"可用 {avail} / {total}",
            "style": "plain",
            "icon": "externaldrive"
        }
    })

# [3,1] 网速
components.append({
    "type": "text",
    "data": {
        "id": "network",
        "content": f"↓ {fmt_speed(speed_down)}\n↑ {fmt_speed(speed_up)}",
        "style": "plain",
        "icon": "network"
    }
})

# [3,2] 热状态
thermal_icon = "thermometer.medium"
if thermal_label in ("很高", "严重"):
    thermal_icon = "thermometer.high"
components.append({
    "type": "text",
    "data": {
        "id": "thermal",
        "content": f"热状态 {thermal_label}",
        "style": "plain",
        "icon": thermal_icon
    }
})

data = {
    "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "title": "系统监控",
    "icon": "desktopcomputer",
    "components": components
}

print(json.dumps(data, ensure_ascii=False))
