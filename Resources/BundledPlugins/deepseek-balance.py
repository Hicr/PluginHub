#!/usr/bin/env python3
# PluginHub:
#   name: DeepSeek
#   description: 监控 DeepSeek API 余额
#   icon: brain.head.profile
#   parameters:
#     - name: API_KEY
#       type: secret
#       label: API Key
#       required: true
#       placeholder: sk-xxx
# /PluginHub

import json
import sys
import urllib.request
import urllib.error
import os
from datetime import datetime, timezone

ENDPOINT = "https://api.deepseek.com/user/balance"


def utc_now_iso():
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


def balance_color(amount):
    if amount <= 5:
        return "#FF3B30"
    if amount <= 20:
        return "#FF9500"
    if amount <= 50:
        return "#FFD60A"
    return "#34C759"


# --- 主逻辑 ---
params = parse_params(sys.argv[1:])
api_key = params.get("API_KEY", "").strip()

if not api_key:
    print("缺少 API_KEY，请在插件设置中配置 DeepSeek API Key", file=sys.stderr)
    sys.exit(1)

try:
    req = urllib.request.Request(
        ENDPOINT,
        headers={"Accept": "application/json", "Authorization": f"Bearer {api_key}"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read())
except urllib.error.HTTPError as e:
    body = e.read().decode("utf-8", errors="replace")
    print(f"HTTP {e.code}: {body}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)

available = data.get("is_available", True)
balances = data.get("balance_infos", [])

info = balances[0] if balances else {}
currency = info.get("currency", "CNY")
total = float(info.get("total_balance", "0"))
granted = float(info.get("granted_balance", "0"))
topped_up = float(info.get("topped_up_balance", "0"))

components = []

# 余额文字（颜色随余额变化）
if not available:
    balance_style = "alert"
    balance_icon = "xmark.circle.fill"
    balance_text = "账户不可用"
elif total <= 5:
    balance_style = "alert"
    balance_icon = "exclamationmark.circle.fill"
    balance_text = f"总余额 ¥{total:.2f}"
elif total <= 20:
    balance_style = "warning"
    balance_icon = "exclamationmark.circle"
    balance_text = f"总余额 ¥{total:.2f}"
elif total <= 50:
    balance_style = "plain"
    balance_icon = "checkmark.circle"
    balance_text = f"总余额 ¥{total:.2f}"
else:
    balance_style = "success"
    balance_icon = "checkmark.circle.fill"
    balance_text = f"总余额 ¥{total:.2f}"

components.append({
    "type": "text",
    "data": {
        "id": "total",
        "content": balance_text,
        "style": balance_style,
        "icon": balance_icon
    }
})

# 充值 + 赠送
components.append({
    "type": "list",
    "data": {
        "id": "detail",
        "style": "simple",
        "items": [
            {
                "title": "充值余额",
                "value": f"¥{topped_up:.2f}",
                "icon": "creditcard.fill",
                "color": "#007AFF"
            },
            {
                "title": "赠送余额",
                "value": f"¥{granted:.2f}",
                "icon": "gift.fill",
                "color": "#34C759" if granted > 0 else "#8E8E93"
            }
        ]
    }
})

badge = f"¥{total:.0f}" if total > 0 else None

print(json.dumps({
    "updatedAt": utc_now_iso(),
    "title": "DeepSeek",
    "icon": "brain.head.profile",
    "badge": badge,
    "components": components,
}, ensure_ascii=False))
