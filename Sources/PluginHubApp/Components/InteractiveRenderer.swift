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
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    if let actions = component.config.actions {
                        for action in actions {
                            performAction(action)
                        }
                    }
                } label: {
                    Text("刮开查看")
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

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
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", payload]
                process.terminationHandler = { _ in
                    DispatchQueue.main.async {
                        onAction?()
                    }
                }
                try? process.run()
            }
        }
    }
}
