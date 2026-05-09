#!/usr/bin/env python3
# PluginHub:
#   name: 喝水提醒
#   description: 定时提醒喝水，追踪每日饮水进度
#   icon: drop.fill
#   parameters:
#     - name: start_hour
#       type: time
#       label: 开始时间
#       default: 9
#     - name: end_hour
#       type: time
#       label: 结束时间
#       default: 20
#     - name: interval_hours
#       type: integer
#       label: 间隔(时)
#       default: 2
#     - name: daily_goal
#       type: integer
#       label: 每日目标
#       default: 8
#     - name: notify
#       type: boolean
#       label: 通知
#       default: true
# /PluginHub

import json
import os
import glob
from datetime import datetime, timezone, timedelta

STATE_DIR = "/tmp/pluginhub_water"
today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

# 配置
start_hour = int(os.environ.get("PLUGINHUB_PARAM_START_HOUR", "9"))
end_hour = int(os.environ.get("PLUGINHUB_PARAM_END_HOUR", "20"))
interval_hours = int(os.environ.get("PLUGINHUB_PARAM_INTERVAL_HOURS", "2"))
daily_goal = int(os.environ.get("PLUGINHUB_PARAM_DAILY_GOAL", "8"))
notify_str = os.environ.get("PLUGINHUB_PARAM_NOTIFY", "true")
notify_enabled = notify_str.lower() in ("1", "true", "yes", "on")

# 读取今日喝水次数
os.makedirs(STATE_DIR, exist_ok=True)
today_file = os.path.join(STATE_DIR, f"{today}.txt")
count = 0
if os.path.exists(today_file):
    with open(today_file) as f:
        count = len([l for l in f if l.strip()])

# 计算下次提醒时间
now = datetime.now()
next_reminder = None
if notify_enabled:
    current_hour = now.hour
    # 找到今天下一个提醒时刻
    for h in range(start_hour, end_hour, interval_hours):
        reminder_time = now.replace(hour=h, minute=0, second=0, microsecond=0)
        if reminder_time > now:
            next_reminder = reminder_time
            break
    # 如果今天没有了，找明天第一个
    if next_reminder is None:
        next_reminder = now.replace(hour=start_hour, minute=0, second=0, microsecond=0) + timedelta(days=1)

# 图标随进度变化
if count == 0:
    icon = "drop"
elif count < daily_goal / 2:
    icon = "drop.fill"
elif count < daily_goal:
    icon = "drop.circle.fill"
else:
    icon = "drop.degreesign.fill"

# 进度条颜色
if count >= daily_goal:
    color = "#34C759"
elif count >= daily_goal * 0.7:
    color = "#FFD60A"
else:
    color = "#007AFF"

components = []

# 喝水进度
components.append({
    "type": "progress",
    "data": {
        "id": "water",
        "label": "喝水",
        "value": count,
        "max": daily_goal,
        "unit": f"/{daily_goal} 杯",
        "color": color,
        "style": "bar"
    }
})

# +/- 按钮
state_file_path = os.path.join(STATE_DIR, f"{today}.txt")
add_cmd = f"echo $(date +%H:%M) >> {state_file_path}"
# macOS sed: 删除最后一行
del_cmd = f"sed -i '' '$d' {state_file_path} 2>/dev/null; true"
components.append({
    "type": "interactive",
    "data": {
        "id": "add",
        "type": "button",
        "config": {
            "actions": [
                {"id": "drink", "label": "+1", "type": "callback", "payload": add_cmd},
                {"id": "undo", "label": "-1", "type": "callback", "payload": del_cmd}
            ]
        }
    }
})

# 状态文字
if count >= daily_goal:
    status = "今日已达标! 🎉"
    style = "success"
elif count > 0:
    remaining = daily_goal - count
    status = f"还差 {remaining} 杯"
    style = "plain"
else:
    status = "今天还没喝水"
    style = "warning"
components.append({
    "type": "text",
    "data": {
        "id": "status",
        "content": status,
        "style": style
    }
})

# 通知
notification = None
if notify_enabled and next_reminder:
    notification = {
        "title": "喝水时间到!",
        "body": f"今天已喝 {count}/{daily_goal} 杯，该喝水了 💧",
        "sound": True,
        "scheduledAt": next_reminder.isoformat() + "Z"
    }

data = {
    "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "title": "喝水提醒",
    "icon": icon,
    "badge": str(count) if count > 0 else None,
    "components": components,
    "notification": notification
}

print(json.dumps(data, ensure_ascii=False))
