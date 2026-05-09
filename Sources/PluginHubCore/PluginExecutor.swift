import Foundation

public struct PluginExecutor: Sendable {
    public var timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 30) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func run(configuration: PluginConfiguration, displayName: String, sharedDir: String? = nil, triggerFile: String? = nil, thermalState: String? = nil) -> PluginSnapshot {
        guard configuration.enabled else {
            return PluginSnapshot(id: configuration.id, pluginName: configuration.name, displayName: displayName, icon: configuration.metadata?.icon)
        }

        guard !configuration.executablePath.isEmpty else {
            return failed(configuration: configuration, displayName: displayName, message: "未配置可执行路径")
        }

        guard FileManager.default.fileExists(atPath: configuration.executablePath) else {
            return failed(configuration: configuration, displayName: displayName, message: "脚本文件不存在，请检查路径")
        }

        let process = Process()
        let executableURL = URL(fileURLWithPath: configuration.executablePath)
        let pluginArguments = parameterArguments(configuration: configuration)
        if executableURL.pathExtension.lowercased() == "py" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", configuration.executablePath] + pluginArguments
        } else {
            process.executableURL = executableURL
            process.arguments = pluginArguments
        }
        var environment = ProcessInfo.processInfo.environment
        if let sharedDir {
            environment["PLUGINHUB_SHARED_DIR"] = sharedDir
        }
        if let triggerFile {
            environment["PLUGINHUB_TRIGGER_FILE"] = triggerFile
        }
        if let thermalState {
            environment["PLUGINHUB_THERMAL_STATE"] = thermalState
        }
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            PluginLogger.log("插件 [\(configuration.name)] 启动失败: \(error.localizedDescription)", level: "ERROR")
            return failed(configuration: configuration, displayName: displayName, message: error.localizedDescription)
        }

        let finished = wait(process: process, timeoutSeconds: timeoutSeconds)
        if !finished {
            process.terminate()
            PluginLogger.log("插件 [\(configuration.name)] 执行超时 (\(timeoutSeconds)s)", level: "ERROR")
            return failed(configuration: configuration, displayName: displayName, message: "插件执行超时")
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let stderrText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            PluginLogger.log("插件 [\(configuration.name)] 执行失败 (code \(process.terminationStatus)): \(stderrText ?? "")", level: "ERROR")
            return failed(configuration: configuration, displayName: displayName, message: stderrText?.isEmpty == false ? stderrText! : "插件退出码 \(process.terminationStatus)")
        }

        do {
            let pluginOutput = try PluginHubJSON.decoder().decode(PluginOutput.self, from: outputData)
            return PluginSnapshot(
                id: configuration.id,
                pluginName: configuration.name,
                displayName: displayName,
                state: .ready,
                components: pluginOutput.components,
                updatedAt: pluginOutput.updatedAt,
                badge: pluginOutput.badge,
                icon: configuration.metadata?.icon,
                title: pluginOutput.title,
                notification: pluginOutput.notification
            )
        } catch {
            PluginLogger.log("插件 [\(configuration.name)] JSON 解析失败: \(error.localizedDescription)", level: "ERROR")
            return failed(configuration: configuration, displayName: displayName, message: "JSON 解析失败：\(error.localizedDescription)")
        }
    }

    public func parameterArguments(configuration: PluginConfiguration) -> [String] {
        configuration.parameterValues
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .flatMap { ["--pluginhub-param", "\($0.key)=\($0.value)"] }
    }

    private func wait(process: Process, timeoutSeconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Date() >= deadline { return false }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return true
    }

    private func failed(configuration: PluginConfiguration, displayName: String, message: String) -> PluginSnapshot {
        PluginSnapshot(
            id: configuration.id,
            pluginName: configuration.name,
            displayName: displayName,
            state: .failed(message),
            components: [],
            updatedAt: Date(),
            icon: configuration.metadata?.icon
        )
    }
}
