import SwiftUI

struct PiecePreviewView: View {
    let title: String
    let kind: TetrominoKind?

    private var blocks: Set<GridPoint> {
        Set(kind?.rotations[0] ?? [])
    }

    var body: some View {
        GroupBox(title) {
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(0..<4, id: \.self) { y in
                    GridRow {
                        ForEach(0..<4, id: \.self) { x in
                            Rectangle()
                                .fill(
                                    blocks.contains(GridPoint(x: x, y: y))
                                        ? kind?.color ?? .clear
                                        : .clear
                                )
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .frame(width: 44, height: 44)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            kind.map { "\(title)、\($0.displayName)" } ?? "\(title)、なし"
        )
    }
}
