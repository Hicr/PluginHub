import Foundation
@testable import PluginHubCore

// 简单的手动验证测试——没有 XCTest/Testing framework 时的替代方案
// 以后安装 Xcode 后再添加正式的单元测试

func runTests() -> Bool {
    var passed = 0
    var failed = 0

    func check(_ condition: Bool, _ name: String) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("  FAIL: \(name)")
        }
    }

    print("=== PluginHubCore 模型测试 ===")

    let json = """
    {
        "updatedAt": "2024-01-15T10:30:00Z",
        "title": "测试插件",
        "icon": "star.fill",
        "badge": "OK",
        "components": [
            {
                "type": "progress",
                "data": {
                    "id": "cpu",
                    "label": "CPU",
                    "value": 50.0,
                    "max": 100.0,
                    "style": "bar"
                }
            },
            {
                "type": "list",
                "data": {
                    "id": "info",
                    "title": "系统信息",
                    "style": "simple",
                    "items": [
                        {"title": "进程数", "value": "320"}
                    ]
                }
            }
        ]
    }
    """

    guard let data = json.data(using: .utf8) else {
        print("JSON 编码失败")
        return false
    }

    do {
        let output = try PluginHubJSON.decoder().decode(PluginOutput.self, from: data)

        check(output.title == "测试插件", "title 正确")
        check(output.icon == "star.fill", "icon 正确")
        check(output.badge == "OK", "badge 正确")
        check(output.components.count == 2, "components 数量为 2")

        if case .progress(let progress) = output.components[0] {
            check(progress.id == "cpu", "progress id")
            check(progress.value == 50.0, "progress value")
            check(progress.style == .bar, "progress style")
        } else {
            failed += 1
            print("  FAIL: 第一个组件应为 progress")
        }

        if case .list(let list) = output.components[1] {
            check(list.id == "info", "list id")
            check(list.items.count == 1, "list items 数量")
            check(list.items[0].title == "进程数", "list item title")
        } else {
            failed += 1
            print("  FAIL: 第二个组件应为 list")
        }

    } catch {
        failed += 1
        print("  FAIL: JSON 解码失败: \(error)")
    }

    print("\n完成: \(passed) 通过, \(failed) 失败")
    return failed == 0
}

// 这个文件需要作为 main 入口运行
// 通过 swift run 的方式验证模型
