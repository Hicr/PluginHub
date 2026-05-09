import Foundation

public enum PluginLogger {
    private static let maxLogFiles = 5

    public static func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [\(level)] \(message)\n"
        print(entry, terminator: "")

        guard let dir = logDirectoryURL() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileURL = dir.appendingPathComponent("pluginhub.log")
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8) ?? Data())
            try? handle.close()
        } else {
            try? entry.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // 轮转大文件
        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 512 * 1024 {
            rotateLogs(dir: dir)
        }
    }

    private static func logDirectoryURL() -> URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("PluginHub/logs", isDirectory: true)
    }

    private static func rotateLogs(dir: URL) {
        for i in stride(from: maxLogFiles - 1, through: 1, by: -1) {
            let old = dir.appendingPathComponent("pluginhub.log.\(i)")
            let new = dir.appendingPathComponent("pluginhub.log.\(i + 1)")
            try? FileManager.default.removeItem(at: new)
            try? FileManager.default.moveItem(at: old, to: new)
        }
        let current = dir.appendingPathComponent("pluginhub.log")
        let rotated = dir.appendingPathComponent("pluginhub.log.1")
        try? FileManager.default.moveItem(at: current, to: rotated)
    }
}
