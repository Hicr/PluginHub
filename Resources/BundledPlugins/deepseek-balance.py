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
from decimal import Decimal, InvalidOperation
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


def money(value, currency):
    symbol = {"CNY": "¥", "USD": "$"}.get(currency)
    return f"{symbol}{value:.2f}" if symbol else f"{value:.2f} {currency}"


def amount(info, key):
    value = Decimal(info[key])
    if not value.is_finite():
        raise ValueError("Invalid balance")
    return value


def balance_components(data):
    available = data["is_available"]
    balances = data["balance_infos"]
    if not isinstance(available, bool) or not isinstance(balances, list):
        raise ValueError("Invalid balance response")
    totals = []
    details = []
    for index, info in enumerate(balances):
        currency = info["currency"]
        total = money(amount(info, "total_balance"), currency)
        totals.append(total)
        details.append({
            "type": "list",
            "data": {
                "id": "detail" if index == 0 else f"detail-{index}",
                "title": currency,
                "style": "simple",
                "items": [
                    {"title": "充值余额", "value": money(amount(info, "topped_up_balance"), currency),
                     "icon": "creditcard.fill"},
                    {"title": "赠送余额", "value": money(amount(info, "granted_balance"), currency),
                     "icon": "gift.fill"},
                ],
            },
        })

    if not available:
        summary = "可用余额不足"
        style = "alert"
    elif not totals:
        summary = "暂无余额明细"
        style = "plain"
    else:
        summary = "总余额"
        style = "plain"

    return [{
        "type": "text",
        "data": {"id": "total", "content": "\n".join([summary, *totals]), "style": style},
    }, *details]


def main():
    api_key = parse_params(sys.argv[1:]).get("API_KEY", "").strip()
    if not api_key:
        sys.exit("请在插件设置中填写并保存 DeepSeek API Key")

    try:
        request = urllib.request.Request(
            ENDPOINT,
            headers={"Accept": "application/json", "Authorization": f"Bearer {api_key}"},
        )
        with urllib.request.urlopen(request, timeout=10) as response:
            components = balance_components(json.load(response))
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            sys.exit("DeepSeek 鉴权失败，请检查 API Key")
        if error.code == 429:
            sys.exit("DeepSeek 请求过于频繁，请稍后刷新")
        sys.exit(f"DeepSeek 查询失败（HTTP {error.code}）")
    except (urllib.error.URLError, TimeoutError):
        sys.exit("无法连接 DeepSeek，请检查网络后重试")
    except (ValueError, TypeError, KeyError, InvalidOperation):
        sys.exit("DeepSeek 返回了无法读取的余额数据")

    print(json.dumps({
        "updatedAt": utc_now_iso(),
        "title": "DeepSeek",
        "icon": "brain.head.profile",
        "components": components,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
