#!/usr/bin/env python3
# PluginHub:
#   name: Hello 模板
#   description: 一个最简单的示例插件，展示 progress、list、text 三种组件
#   icon: star.fill
#   parameters:
#     - name: title
#       type: string
#       label: 标题文字
#       default: Hello PluginHub
# /PluginHub

import json
import os
from datetime import datetime, timezone

title = os.environ.get("PLUGINHUB_PARAM_TITLE", "Hello PluginHub")

data = {
    "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "title": "Hello 模板",
    "icon": "star.fill",
    "components": [
        {
            "type": "progress",
            "data": {
                "id": "demo-progress",
                "label": "进度示例",
                "value": 65,
                "max": 100,
                "unit": "%",
                "color": "#007AFF",
                "style": "bar"
            }
        },
        {
            "type": "list",
            "data": {
                "id": "demo-list",
                "title": "列表示例",
                "style": "detailed",
                "items": [
                    {"title": "CPU", "value": "25%", "icon": "cpu", "color": "#34C759"},
                    {"title": "内存", "value": "60%", "icon": "memorychip", "color": "#FFD60A"},
                    {"title": "磁盘", "value": "40%", "icon": "externaldrive", "color": "#007AFF"}
                ]
            }
        },
        {
            "type": "text",
            "data": {
                "id": "demo-text",
                "content": title,
                "style": "success",
                "icon": "hand.wave"
            }
        }
    ]
}

print(json.dumps(data, ensure_ascii=False))
