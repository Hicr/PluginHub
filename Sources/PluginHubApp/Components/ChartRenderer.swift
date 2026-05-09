import SwiftUI
import Charts
import PluginHubCore

struct ChartRenderer: View {
    let component: ChartComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = component.title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if component.data.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                chartContent
                    .frame(height: 180)
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        switch component.type {
        case .line:
            Chart(component.data) { point in
                LineMark(
                    x: .value(component.xLabel ?? "", point.label),
                    y: .value(component.yLabel ?? "", point.value)
                )
                .foregroundStyle(by: .value("系列", point.series ?? ""))
            }
            .chartLegend(.visible)

        case .bar:
            Chart(component.data) { point in
                BarMark(
                    x: .value(component.xLabel ?? "", point.label),
                    y: .value(component.yLabel ?? "", point.value)
                )
                .foregroundStyle(by: .value("系列", point.series ?? ""))
            }
            .chartLegend(.visible)

        case .pie:
            if #available(macOS 14.0, *) {
                Chart(component.data) { point in
                    SectorMark(
                        angle: .value(component.yLabel ?? "", point.value),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value(component.xLabel ?? "", point.label))
                }
            } else {
                Chart(component.data) { point in
                    BarMark(
                        x: .value(component.xLabel ?? "", point.label),
                        y: .value(component.yLabel ?? "", point.value)
                    )
                    .foregroundStyle(by: .value(component.xLabel ?? "", point.label))
                }
            }
        }
    }
}
