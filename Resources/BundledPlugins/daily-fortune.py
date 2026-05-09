#!/usr/bin/env python3
# PluginHub:
#   name: 每日签运
#   description: 每天刮一刮，看看今日运势
#   icon: sparkles
#   parameters:
#     - name: fortunes
#       type: textarea
#       label: 签文列表
#       default: "大吉大利 🍀|success\\n万事如意 ✨|success\\n好运爆棚 💥|success\\n心想事成 🌈|success\\n贵人相助 🤝|success\\n宜写代码 💻|success\\n宜摸鱼 🐟|plain\\n宜喝咖啡 ☕|plain\\n忌加班 😴|warning\\n忌焦虑 🧘|warning\\n小有波折 🌧|warning\\n平平淡淡 😶|plain\\n破财消灾 💸|alert\\n诸事不宜 🚫|alert\\n桃花朵朵 🌸|success\\n灵感迸发 💡|success\\n财源滚滚 💰|success\\n步步高升 📈|success\\n有惊无险 😅|warning\\n柳暗花明 🌅|plain"
# /PluginHub

import json
import os
import random
import sys
from datetime import datetime, timezone, date

STATE_DIR = "/tmp/pluginhub_fortunes"


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


def parse_fortunes(raw):
    raw = raw.strip().strip('"')
    raw = raw.replace("\\n", "\n")
    result = []
    for line in raw.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        parts = line.rsplit("|", 1)
        if len(parts) == 2:
            result.append({"text": parts[0].strip(), "style": parts[1].strip()})
        else:
            result.append({"text": line, "style": "plain"})
    return result if result else [{"text": "今日无事 😐", "style": "plain"}]


def cn_date(dt):
    months = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二"]
    days = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十", "卅一"]
    return f"{months[dt.month - 1]}月{days[dt.day - 1]}日"


# --- 主逻辑 ---
params = parse_params(sys.argv[1:])
fortunes_raw = params.get("fortunes", "")
fortunes = parse_fortunes(fortunes_raw)

today = date.today().isoformat()
today_dt = date.today()
os.makedirs(STATE_DIR, exist_ok=True)
today_file = os.path.join(STATE_DIR, f"{today}.txt")
counter_file = os.path.join(STATE_DIR, f"{today}.cnt")

# 读取今天的刮卡次数
counter = 0
if os.path.exists(counter_file):
    try:
        with open(counter_file) as f:
            counter = int(f.read().strip())
    except Exception:
        pass

if os.path.exists(today_file):
    # 今天已签：显示结果 + 再刮一次按钮
    try:
        with open(today_file) as f:
            entry = json.loads(f.read().strip())
        ft_text = entry.get("text", "?")
    except Exception:
        ft_text = "?"

    # 再刮一次：删文件、加计数
    reset_cmd = f"rm -f {today_file} && echo {counter + 1} > {counter_file}"

    components = [
        {
            "type": "interactive",
            "data": {
                "id": "scratch",
                "type": "scratchcard",
                "config": {
                    "actions": [
                        {"id": "reset", "label": "再刮一次", "type": "callback", "payload": reset_cmd}
                    ]
                },
                "state": {"revealed": "true", "prize": f"{cn_date(today_dt)}｜{ft_text}"}
            }
        },
    ]
    badge = None
else:
    # 未签：随机生成
    seed_str = f"{today}-{counter}"
    random.seed(seed_str)
    fortune = random.choice(fortunes)

    import base64
    fortune_json = json.dumps({"text": fortune["text"], "style": fortune["style"]}, ensure_ascii=False)
    b64 = base64.b64encode(fortune_json.encode()).decode()
    cmd = f"echo {b64} | base64 -d > {today_file}"

    components = [
        {
            "type": "interactive",
            "data": {
                "id": "scratch",
                "type": "scratchcard",
                "config": {
                    "actions": [
                        {"id": "reveal", "label": "刮开查看", "type": "callback", "payload": cmd}
                    ]
                },
                "state": {"revealed": "false", "prize": f"{cn_date(today_dt)}｜{fortune['text']}"}
            }
        },
    ]
    badge = "未签"

print(json.dumps({
    "updatedAt": utc_now(),
    "title": "每日签运",
    "icon": "sparkles",
    "badge": badge,
    "components": components,
}, ensure_ascii=False))
