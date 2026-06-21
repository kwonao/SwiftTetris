import SwiftUI

struct PiecePreviewView: View {
    let title: String
    let kind: TetrominoKind?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Canvas { context, size in
                guard let kind else { return }
                let blocks = kind.rotations[0]
                let minX = blocks.map(\.x).min() ?? 0
                let maxX = blocks.map(\.x).max() ?? 0
                let minY = blocks.map(\.y).min() ?? 0
                let maxY = blocks.map(\.y).max() ?? 0
                let width = maxX - minX + 1
                let height = maxY - minY + 1
                let cell = min(size.width / CGFloat(width), size.height / CGFloat(height)) * 0.72
                let offsetX = (size.width - CGFloat(width) * cell) / 2
                let offsetY = (size.height - CGFloat(height) * cell) / 2

                for block in blocks {
                    let rect = CGRect(
                        x: offsetX + CGFloat(block.x - minX) * cell,
                        y: offsetY + CGFloat(block.y - minY) * cell,
                        width: cell,
                        height: cell
                    ).insetBy(dx: 1, dy: 1)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: cell * 0.16),
                        with: .color(kind.color)
                    )
                }
            }
            .frame(width: 82, height: 62)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            kind.map { "\(title)、\($0.displayName)" } ?? "\(title)、なし"
        )
    }
}
