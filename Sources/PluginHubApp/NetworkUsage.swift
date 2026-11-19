import SwiftUI
import AppKit
import PluginHubCore

private struct NetworkCounter: Codable, Sendable {
    var name: String
    var incoming: Double
    var outgoing: Double
}

private struct NetworkDay: Codable {
    var date: String
    var counters: [String: NetworkCounter]
}

@MainActor
final class NetworkUsage: ObservableObject {
    nonisolated static let pluginStateID = "builtin-network-usage"
    static let continuousKey = "continuous"

    private var enabled = false
    private var continuous = true
    private var interval = 5
    private var samplingGeneration = 0

    func configure(_ plugin: PluginConfiguration) {
        let newInterval = max(1, plugin.refreshIntervalSeconds)
        let newContinuous = plugin.parameterValues[Self.continuousKey] != "false"
        guard enabled != plugin.enabled || interval != newInterval || continuous != newContinuous else { return }
        enabled = plugin.enabled
        interval = newInterval
        continuous = newContinuous
        schedule()
    }

    @Published private(set) var message = "等待采集"
    @Published private(set) var busy = false
    @Published private(set) var updated: Date?
    @Published fileprivate var rates: [String: NetworkCounter] = [:]
    @Published fileprivate var totals: [String: NetworkCounter] = [:]
    var visible = false {
        didSet {
            if visible != oldValue && !continuous { schedule() }
        }
    }
    private var previous: [String: NetworkCounter] = [:]
    private var lastUptime: TimeInterval?
    private var timer: Task<Void, Never>?
    private var day = Calendar.current.startOfDay(for: Date()).description
    private let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PluginHub/network-usage.json")

    init() {
        if let data = try? Data(contentsOf: file),
           let saved = try? PluginHubJSON.decoder().decode(NetworkDay.self, from: data), saved.date == day {
            totals = saved.counters
        }
    }

    private func schedule() {
        timer?.cancel()
        guard enabled && (continuous || visible) else {
            samplingGeneration += 1
            previous = [:]; lastUptime = nil; rates = [:]
            message = "采集已暂停"
            return
        }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                let delay = self?.interval ?? 5
                do { try await Task.sleep(for: .seconds(max(1, delay))) } catch { return }
            }
        }
    }

    func refresh() {
        guard enabled, !busy else { return }
        let generation = samplingGeneration
        busy = true
        Task {
            defer { busy = false }
            do {
                let counters = try await Task.detached(priority: .utility) {
                    try Self.collect()
                }.value
                guard generation == samplingGeneration else { return }
                let now = Date()
                let newDay = Calendar.current.startOfDay(for: now).description
                if newDay != day { day = newDay; totals = [:]; previous = [:]; lastUptime = nil }
                let uptime = ProcessInfo.processInfo.systemUptime
                let elapsed = uptime - (lastUptime ?? uptime)
                var changes: [String: NetworkCounter] = [:]
                for (identity, counter) in counters {
                    guard let old = previous[identity], elapsed > 0,
                          elapsed < Double(max(1, interval)) * 3,
                          counter.incoming >= old.incoming, counter.outgoing >= old.outgoing else { continue }
                    let incoming = counter.incoming - old.incoming
                    let outgoing = counter.outgoing - old.outgoing
                    var rate = changes[counter.name] ?? NetworkCounter(name: counter.name, incoming: 0, outgoing: 0)
                    rate.incoming += incoming / elapsed; rate.outgoing += outgoing / elapsed
                    changes[counter.name] = rate
                    var total = totals[counter.name] ?? NetworkCounter(name: counter.name, incoming: 0, outgoing: 0)
                    total.incoming += incoming; total.outgoing += outgoing
                    totals[counter.name] = total
                }
                message = lastUptime == nil ? "等待下一次采集" : "今日累计仅覆盖已采集时段"
                rates = changes; previous = counters; lastUptime = uptime; updated = now
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try PluginHubJSON.encoder().encode(NetworkDay(date: day, counters: totals)).write(to: file, options: .atomic)
            } catch {
                guard generation == samplingGeneration else { return }
                previous = [:]; lastUptime = nil; rates = [:]
                message = "采集或保存失败：\(error.localizedDescription)"
            }
        }
    }

    nonisolated private static func collect() throws -> [String: NetworkCounter] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-n", "-P", "-L", "1", "-J", "bytes_in,bytes_out", "-t", "external"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: watchdog)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "NetworkUsage", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "nettop 无法读取网络计数"])
        }
        var result: [String: NetworkCounter] = [:]
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n").dropFirst() {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 3, let dot = fields[0].lastIndex(of: "."),
                  let pid = Int32(fields[0][fields[0].index(after: dot)...]),
                  let incoming = Double(fields[1]), let outgoing = Double(fields[2]) else { continue }
            var info = proc_bsdinfo()
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 else { continue }
            var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            proc_pidpath(pid, &path, UInt32(path.count))
            let executable = String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            var name = String(fields[0][..<dot])
            if let range = executable.range(of: ".app/") {
                let bundleURL = URL(fileURLWithPath: String(executable[..<range.lowerBound]) + ".app")
                let bundle = Bundle(url: bundleURL)
                name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? bundleURL.deletingPathExtension().lastPathComponent
            }
            let identity = "\(pid)-\(info.pbi_start_tvsec)-\(info.pbi_start_tvusec)"
            result[identity] = NetworkCounter(name: name, incoming: incoming, outgoing: outgoing)
        }
        return result
    }
}

struct NetworkUsageCard: View {
    @ObservedObject var usage: NetworkUsage
    let title: String
    @State private var selection = 0
    @ScaledMetric(relativeTo: .body) private var rowHeight = 20.0
    private let rowSpacing: CGFloat = 4
    private let rowLimit = 5
    private let titles = ["实时上传", "实时下载", "今日上传", "今日下载"]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.isEmpty ? "应用网络用量" : title).font(.headline)
                Spacer()
                Button { usage.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(usage.busy).help("立即刷新")
            }
            Picker("榜单", selection: $selection) {
                ForEach(0..<4) { Text(titles[$0]).tag($0) }
            }.pickerStyle(.segmented)
            let counters = selection < 2 ? usage.rates : usage.totals
            let rows = counters.values.filter { value($0) > 0 }.sorted { value($0) > value($1) }.prefix(rowLimit)
            VStack(alignment: .leading, spacing: rowSpacing) {
                if rows.isEmpty {
                    Text(selection < 2 ? "本次采样未检测到流量" : "今日暂无已采集用量")
                        .foregroundStyle(.secondary)
                        .frame(height: rowHeight)
                }
                ForEach(Array(rows), id: \.name) { row in
                    HStack {
                        Text(row.name).lineLimit(1)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(min(value(row), Double(Int64.max - 1024))), countStyle: .decimal) + (selection < 2 ? "/s" : ""))
                            .monospacedDigit()
                    }
                    .frame(height: rowHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: rowHeight * CGFloat(rowLimit) + rowSpacing * CGFloat(rowLimit - 1), alignment: .top)

            Text(usage.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(usage.message)
            if let updated = usage.updated {
                Text("上次采集 \(updated.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("上次采集 —")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .modifier(NetworkCardBackground())
    }
    private func value(_ counter: NetworkCounter) -> Double {
        selection % 2 == 0 ? counter.outgoing : counter.incoming
    }
}
