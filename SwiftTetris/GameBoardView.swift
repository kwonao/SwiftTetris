import SwiftUI

struct GameBoardView: View {
    let state: GameState

    var body: some View {
        let cells = state.visibleCells
        let ghostCells = state.ghostCells

        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(cells.indices, id: \.self) { y in
                GridRow {
                    ForEach(cells[y].indices, id: \.self) { x in
                        let point = GridPoint(x: x, y: y)

                        CellView(
                            kind: cells[y][x],
                            isGhost: ghostCells.contains(point)
                        )
                    }
                }
            }
        }
        .aspectRatio(
            CGFloat(GameState.columns) / CGFloat(GameState.rows),
            contentMode: .fit
        )
        .padding(4)
        .background(.secondary.opacity(0.1))
        .border(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("テトリスのゲーム盤")
    }
}

private struct CellView: View {
    let kind: TetrominoKind?
    let isGhost: Bool

    var body: some View {
        Rectangle()
            .fill(kind?.color ?? .secondary.opacity(0.08))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if kind == nil, isGhost {
                    Rectangle()
                        .stroke(.secondary, lineWidth: 1)
                }
            }
    }
}
