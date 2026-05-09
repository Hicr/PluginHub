import Foundation

public enum PluginMetadataParser {
    private static let beginMarker = "PluginHub:"
    private static let endMarker = "/PluginHub"

    public static func parse(fileURL: URL) -> PluginMetadata? {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return parse(text: text)
    }

    public static func parse(text: String) -> PluginMetadata? {
        var isCollecting = false
        var lines: [String] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).prefix(80) {
            let line = stripCommentPrefix(String(rawLine))
            if line.trimmingCharacters(in: .whitespaces).hasPrefix(beginMarker) {
                isCollecting = true
                let afterMarker = line.components(separatedBy: beginMarker).dropFirst().joined(separator: beginMarker)
                if !afterMarker.trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.append(afterMarker)
                }
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).hasPrefix(endMarker) {
                break
            }

            if isCollecting {
                lines.append(line)
            }
        }

        let yamlText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !yamlText.isEmpty else { return nil }

        // 先尝试 JSON
        if let data = yamlText.data(using: .utf8),
           let result = try? PluginHubJSON.decoder().decode(PluginMetadata.self, from: data) {
            return result
        }

        // 回退到简单 YAML 解析
        return parseYAML(yamlText)
    }

    private static func parseYAML(_ text: String) -> PluginMetadata? {
        var name: String?
        var description: String?
        var icon: String?
        var parameters: [PluginParameterMetadata] = []
        var currentParam: [String: String] = [:]
        var currentOptions: [PluginParameterOption] = []
        var parsingParams = false
        var inOptions = false

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("- name:") {
                if let param = buildParam(currentParam, currentOptions) {
                    parameters.append(param)
                }
                currentParam = [:]
                currentOptions = []
                inOptions = false
                parsingParams = true
                let value = trimmed.dropFirst("- name:".count).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { currentParam["name"] = value }
                continue
            }

            if parsingParams && !inOptions && trimmed.hasPrefix("- ") {
                if let param = buildParam(currentParam, currentOptions) {
                    parameters.append(param)
                }
                currentParam = [:]
                currentOptions = []
                continue
            }

            if trimmed.contains(":") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""

                if key == "parameters" {
                    parsingParams = true
                    continue
                }

                if key == "options" {
                    inOptions = true
                    continue
                }

                if !parsingParams {
                    switch key {
                    case "name": name = value
                    case "description": description = value
                    case "icon": icon = value
                    default: break
                    }
                } else if inOptions {
                    let optKey = key.hasPrefix("- ") ? String(key.dropFirst(2)) : key
                    if optKey == "label" {
                        currentOptions.append(PluginParameterOption(label: value, value: ""))
                    } else if optKey == "value", let last = currentOptions.last {
                        currentOptions[currentOptions.count - 1] = PluginParameterOption(label: last.label, value: value)
                    }
                } else {
                    currentParam[key] = value
                }
            }
        }

        if let param = buildParam(currentParam, currentOptions) {
            parameters.append(param)
        }

        guard name != nil || !parameters.isEmpty else { return nil }
        return PluginMetadata(name: name, description: description, icon: icon, parameters: parameters)
    }

    private static func buildParam(_ dict: [String: String], _ options: [PluginParameterOption] = []) -> PluginParameterMetadata? {
        guard let name = dict["name"] else { return nil }
        let type = PluginParameterType(rawValue: dict["type"] ?? "") ?? .string
        return PluginParameterMetadata(
            name: name,
            label: dict["label"],
            type: type,
            required: dict["required"] == "true",
            placeholder: dict["placeholder"],
            defaultValue: dict["default"],
            options: options
        )
    }

    private static func stripCommentPrefix(_ line: String) -> String {
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLeading.hasPrefix("#") else {
            return line
        }
        return String(trimmedLeading.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
}
