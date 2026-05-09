#!/usr/bin/env python3
# PluginHub:
#   name: 网络延迟
#   description: 监控常用网站的延迟
#   icon: network
#   parameters:
#     - name: hosts
#       type: string
#       label: 监控站点
#       default: google.com,github.com,baidu.com
# /PluginHub

import json
import subprocess
import os
from datetime import datetime, timezone


def ping_host(host):
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-t", "3", host],
            capture_output=True, text=True, timeout=5
        )
        for line in result.stdout.split("\n"):
            if "time=" in line:
                # 格式: 64 bytes from x.x.x.x: icmp_seq=0 ttl=117 time=12.3 ms
                time_str = line.split("time=")[-1].split(" ")[0]
                return float(time_str)
    except Exception:
        pass
    return None


def latency_color(ms):
    if ms is None:
        return "#FF3B30"
    if ms < 50:
        return "#34C759"
    if ms < 100:
        return "#FFD60A"
    return "#FF3B30"


def latency_text(ms):
    if ms is None:
        return "超时"
    return f"{ms:.0f} ms"


# 从环境变量或默认值获取监控站点列表
hosts_raw = os.environ.get("PLUGINHUB_PARAM_HOSTS", "google.com,github.com,baidu.com")
hosts = [h.strip() for h in hosts_raw.split(",") if h.strip()]

items = []
for host in hosts:
    ms = ping_host(host)
    items.append({
        "title": host,
        "value": latency_text(ms),
        "icon": "circle.fill" if ms is not None else "xmark.circle.fill",
        "color": latency_color(ms)
    })

# 统计
online = sum(1 for item in items if item["value"] != "超时")
badge = f"{online}/{len(items)}" if items else None

data = {
    "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "title": "网络延迟",
    "icon": "network",
    "badge": badge,
    "components": [
        {
            "type": "list",
            "data": {
                "id": "ping",
                "title": "Ping 延迟",
                "style": "detailed",
                "items": items
            }
        }
    ]
}

print(json.dumps(data, ensure_ascii=False))
