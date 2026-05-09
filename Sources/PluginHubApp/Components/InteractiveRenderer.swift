import SwiftUI
import AppKit
import PluginHubCore

struct InteractiveRenderer: View {
    let component: InteractiveComponent
    var onAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch component.type {
            case .button:
                buttonView
            case .input:
                inputView
            case .toggle:
                toggleView
            case .scratchcard:
                scratchcardView
            }
        }
    }

    // MARK: - Button

    @ViewBuilder
    private var buttonView: some View {
        if let actions = component.config.actions {
            HStack(spacing: 6) {
                ForEach(actions, id: \.id) { action in
                    Button {
                        performAction(action)
                    } label: {
                        Text(action.label)
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Input

    @State private var inputText: String = ""

    private var inputView: some View {
        HStack(spacing: 6) {
            TextField(component.config.description ?? "", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            if let actions = component.config.actions {
                ForEach(actions, id: \.id) { action in
                    Button(action.label) {
                        performAction(action)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Toggle

    @State private var isOn: Bool = false

    private var toggleView: some View {
        Toggle(isOn: $isOn) {
            if let desc = component.config.description {
                Text(desc)
                    .font(.callout)
            }
        }
        .toggleStyle(.switch)
        .onChange(of: isOn) { _ in
            if let actions = component.config.actions {
                for action in actions {
                    performAction(action)
                }
            }
        }
    }

    // MARK: - Scratchcard

    @State private var scratchProgress: Double = 0

    private var scratchcardView: some View {
        VStack(spacing: 6) {
            if component.state?["revealed"] == "true" {
                if let prize = component.state?["prize"] {
                    Button {
                        if let actions = component.config.actions {
                            for action in actions {
                                performAction(action)
                            }
                        }
                    } label: {
                        Text(prize)
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ZStack {
                    // 被遮住的签文（保持高度一致）
                    if let prize = component.state?["prize"] {
                        Text(prize)
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    }

                    // 刮刮乐遮罩
                    ScratchCardOverlay(
                        onScratchProgress: { pct in
                            scratchProgress = pct
                        },
                        onReveal: {
                            if let actions = component.config.actions {
                                for action in actions {
                                    performAction(action)
                                }
                            }
                        }
                    )
                    .padding(8)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private let revealThreshold = 0.5

    // MARK: - Action

    private func performAction(_ action: InteractiveAction) {
        switch action.type {
        case .url:
            if let payload = action.payload, let url = URL(string: payload) {
                NSWorkspace.shared.open(url)
            }
        case .copy:
            if let payload = action.payload {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(payload, forType: .string)
            }
        case .callback:
            if let payload = action.payload {
                DispatchQueue.global().async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    process.arguments = ["-c", payload]
                    process.launch()
                    process.waitUntilExit()
                    DispatchQueue.main.async {
                        onAction?()
                    }
                }
            }
        }
    }
}
