import SwiftUI

struct GameBoardView: View {
    let game: GameEngine

    private var activeCells: [GridPoint: TetrominoKind] {
        guard let piece = game.activePiece else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: piece.blocks.map { ($0, piece.kind) }
        )
    }

    private var ghostCells: Set<GridPoint> {
        Set(game.ghostBlocks)
    }

    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(GameEngine.columns)
            let cellHeight = size.height / CGFloat(GameEngine.rows)

            for row in 0..<GameEngine.rows {
                for column in 0..<GameEngine.columns {
                    let point = GridPoint(x: column, y: row)
                    let rect = CGRect(
                        x: CGFloat(column) * cellWidth,
                        y: CGFloat(row) * cellHeight,
                        width: cellWidth,
                        height: cellHeight
                    ).insetBy(dx: 1.2, dy: 1.2)

                    if let kind = activeCells[point] ?? game.settledKind(at: point) {
                        drawBlock(kind: kind, in: rect, context: &context)
                    } else if ghostCells.contains(point) {
                        let path = Path(roundedRect: rect, cornerRadius: cellWidth * 0.16)
                        context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
                    } else {
                        let path = Path(roundedRect: rect, cornerRadius: cellWidth * 0.12)
                        context.fill(path, with: .color(.white.opacity(0.035)))
                    }
                }
            }
        }
        .aspectRatio(
            CGFloat(GameEngine.columns) / CGFloat(GameEngine.rows),
            contentMode: .fit
        )
        .padding(7)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityLabel("テトリスのゲーム盤")
    }

    private func drawBlock(
        kind: TetrominoKind,
        in rect: CGRect,
        context: inout GraphicsContext
    ) {
        let cornerRadius = rect.width * 0.16
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        context.fill(path, with: .color(kind.color))

        let highlight = CGRect(
            x: rect.minX + rect.width * 0.12,
            y: rect.minY + rect.height * 0.1,
            width: rect.width * 0.76,
            height: max(1, rect.height * 0.12)
        )
        context.fill(
            Path(roundedRect: highlight, cornerRadius: highlight.height / 2),
            with: .color(.white.opacity(0.38))
        )
    }
}
