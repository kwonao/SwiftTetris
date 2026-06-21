import Foundation

/// 盤面上の位置を表す値型です。
/// `Hashable` に準拠することで、セルの集合や差分判定にも利用できます。
nonisolated struct GridPoint: Hashable, Sendable {
    var x: Int
    var y: Int

    static func + (lhs: GridPoint, rhs: GridPoint) -> GridPoint {
        GridPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}

/// テトリミノの7種類です。
/// `CaseIterable` は7-bagを作る際に全ケースを列挙するために使います。
nonisolated enum TetrominoKind: String, CaseIterable, Sendable {
    case i, o, t, s, z, j, l

    var displayName: String {
        rawValue.uppercased()
    }

    /// 各回転状態を4×4のローカル座標として定義しています。
    var rotations: [[GridPoint]] {
        switch self {
        case .i:
            [
                points((0, 1), (1, 1), (2, 1), (3, 1)),
                points((2, 0), (2, 1), (2, 2), (2, 3)),
                points((0, 2), (1, 2), (2, 2), (3, 2)),
                points((1, 0), (1, 1), (1, 2), (1, 3))
            ]
        case .o:
            [
                points((1, 0), (2, 0), (1, 1), (2, 1))
            ]
        case .t:
            [
                points((1, 0), (0, 1), (1, 1), (2, 1)),
                points((1, 0), (1, 1), (2, 1), (1, 2)),
                points((0, 1), (1, 1), (2, 1), (1, 2)),
                points((1, 0), (0, 1), (1, 1), (1, 2))
            ]
        case .s:
            [
                points((1, 0), (2, 0), (0, 1), (1, 1)),
                points((1, 0), (1, 1), (2, 1), (2, 2)),
                points((1, 1), (2, 1), (0, 2), (1, 2)),
                points((0, 0), (0, 1), (1, 1), (1, 2))
            ]
        case .z:
            [
                points((0, 0), (1, 0), (1, 1), (2, 1)),
                points((2, 0), (1, 1), (2, 1), (1, 2)),
                points((0, 1), (1, 1), (1, 2), (2, 2)),
                points((1, 0), (0, 1), (1, 1), (0, 2))
            ]
        case .j:
            [
                points((0, 0), (0, 1), (1, 1), (2, 1)),
                points((1, 0), (2, 0), (1, 1), (1, 2)),
                points((0, 1), (1, 1), (2, 1), (2, 2)),
                points((1, 0), (1, 1), (0, 2), (1, 2))
            ]
        case .l:
            [
                points((2, 0), (0, 1), (1, 1), (2, 1)),
                points((1, 0), (1, 1), (1, 2), (2, 2)),
                points((0, 1), (1, 1), (2, 1), (0, 2)),
                points((0, 0), (1, 0), (1, 1), (1, 2))
            ]
        }
    }
}

nonisolated private func points(_ values: (Int, Int)...) -> [GridPoint] {
    values.map { GridPoint(x: $0.0, y: $0.1) }
}

/// 落下中のテトリミノです。盤面自体とは別の値として管理します。
nonisolated struct ActivePiece: Sendable {
    var kind: TetrominoKind
    var origin: GridPoint
    var rotationIndex = 0

    var localBlocks: [GridPoint] {
        kind.rotations[rotationIndex]
    }

    var blocks: [GridPoint] {
        localBlocks.map { $0 + origin }
    }

    func moved(x: Int = 0, y: Int = 0) -> ActivePiece {
        var copy = self
        copy.origin.x += x
        copy.origin.y += y
        return copy
    }

    func rotated(clockwise: Bool) -> ActivePiece {
        var copy = self
        let count = kind.rotations.count
        copy.rotationIndex = (rotationIndex + (clockwise ? 1 : count - 1)) % count
        return copy
    }
}
