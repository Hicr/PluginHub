import SwiftUI

struct ScratchCardOverlay: View {
    let onScratchProgress: (Double) -> Void
    let onReveal: () -> Void

    private let gridSize = 25
    private let revealThreshold = 0.5

    @State private var scratched = Set<Int>()
    @State private var isRevealed = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cellW = size.width / CGFloat(gridSize)
            let cellH = size.height / CGFloat(gridSize)

            ZStack {
                // 灰色遮罩
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray))

                // 提示文字
                if scratched.isEmpty {
                    Text("鼠标拖拽刮开")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.6))
                }

                // 刮开区域 = 用单条 Path 连续擦除，无缝隙
                scratchPath(cellW: cellW, cellH: cellH)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .opacity(isRevealed ? 0 : 1)
            .animation(.easeOut(duration: 0.3), value: isRevealed)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        guard !isRevealed else { return }
                        scratch(at: value.location, cellW: cellW, cellH: cellH)
                    }
            )
        }
    }

    private func scratchPath(cellW: CGFloat, cellH: CGFloat) -> Path {
        var path = Path()
        for idx in scratched {
            let c = idx % gridSize
            let r = idx / gridSize
            let rect = CGRect(
                x: CGFloat(c) * cellW,
                y: CGFloat(r) * cellH,
                width: cellW + 1,
                height: cellH + 1
            )
            path.addRect(rect)
        }
        return path
    }

    private func scratch(at point: CGPoint, cellW: CGFloat, cellH: CGFloat) {
        let col = Int(point.x / cellW)
        let row = Int(point.y / cellH)
        guard col >= 0, col < gridSize, row >= 0, row < gridSize else { return }

        var changed = false
        for dc in -1...1 {
            for dr in -1...1 {
                let c = col + dc, r = row + dr
                guard c >= 0, c < gridSize, r >= 0, r < gridSize else { continue }
                if scratched.insert(r * gridSize + c).inserted {
                    changed = true
                }
            }
        }

        if changed {
            let pct = Double(scratched.count) / Double(gridSize * gridSize)
            onScratchProgress(pct)
            if pct >= revealThreshold {
                isRevealed = true
                onReveal()
            }
        }
    }
}
