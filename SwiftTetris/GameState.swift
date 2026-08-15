import Foundation

/// 画面を描画するために必要な、テトリスの唯一の状態です。
///
/// Viewはこの値を読むだけで、状態変更は`reduce(_:)`に集約します。
struct GameState {
    static let columns = 10
    static let rows = 20

    private(set) var board: [[TetrominoKind?]]
    private(set) var activePiece: ActivePiece?
    private(set) var nextKind: TetrominoKind
    private(set) var heldKind: TetrominoKind?
    private(set) var score = 0
    private(set) var clearedLines = 0
    private(set) var phase: GamePhase = .running
    private(set) var gameID: Int

    private var bag: [TetrominoKind]
    private var canHold = true

    init(gameID: Int = 0) {
        var bag = TetrominoKind.allCases.shuffled()
        let firstKind = bag.removeLast()
        let secondKind = bag.removeLast()

        self.board = Self.emptyBoard()
        self.bag = bag
        self.nextKind = secondKind
        self.gameID = gameID
        self.activePiece = ActivePiece(
            kind: firstKind,
            origin: Self.spawnOrigin
        )
    }

    // MARK: - Derived state

    /// 保存する必要のない値は、元の状態からその都度導出します。
    var level: Int {
        clearedLines / 10 + 1
    }

    var tickInterval: Duration {
        .milliseconds(700)
    }

    /// 固定済み盤面と落下中のピースを合成した、View表示用のセルです。
    var visibleCells: [[TetrominoKind?]] {
        var cells = board

        if let activePiece {
            for block in activePiece.blocks
            where (0..<Self.columns).contains(block.x)
                && (0..<Self.rows).contains(block.y) {
                cells[block.y][block.x] = activePiece.kind
            }
        }

        return cells
    }

    var ghostCells: Set<GridPoint> {
        guard var ghost = activePiece else { return [] }

        while isValid(ghost.moved(y: 1)) {
            ghost = ghost.moved(y: 1)
        }

        return Set(ghost.blocks)
    }

    // MARK: - Update

    /// すべての状態変更が通る、唯一の入口です。
    mutating func reduce(_ action: GameAction) {
        switch action {
        case .newGame:
            self = GameState(gameID: gameID + 1)
        case .togglePause:
            togglePause()
        case .pause:
            pause()
        case .tick:
            tick()
        case .moveLeft:
            moveActivePiece(x: -1)
        case .moveRight:
            moveActivePiece(x: 1)
        case .softDrop:
            softDrop()
        case .hardDrop:
            hardDrop()
        case let .rotate(clockwise):
            rotate(clockwise: clockwise)
        case .hold:
            hold()
        }
    }

    private mutating func togglePause() {
        switch phase {
        case .running:
            phase = .paused
        case .paused:
            phase = .running
        case .gameOver:
            break
        }
    }

    private mutating func pause() {
        if phase == .running {
            phase = .paused
        }
    }

    private mutating func tick() {
        guard phase == .running, let piece = activePiece else { return }
        let candidate = piece.moved(y: 1)

        if isValid(candidate) {
            activePiece = candidate
        } else {
            lockPiece()
        }
    }

    private mutating func moveActivePiece(x: Int) {
        guard phase == .running, let piece = activePiece else { return }
        let candidate = piece.moved(x: x)

        if isValid(candidate) {
            activePiece = candidate
        }
    }

    private mutating func softDrop() {
        guard phase == .running, let piece = activePiece else { return }
        let candidate = piece.moved(y: 1)

        if isValid(candidate) {
            activePiece = candidate
        } else {
            lockPiece()
        }
    }

    private mutating func hardDrop() {
        guard phase == .running, var piece = activePiece else { return }
        var distance = 0

        while isValid(piece.moved(y: 1)) {
            piece = piece.moved(y: 1)
            distance += 1
        }

        activePiece = piece
        score += distance * 2
        lockPiece()
    }

    private mutating func rotate(clockwise: Bool) {
        guard phase == .running, let piece = activePiece else { return }
        let fromRotation = piece.rotationIndex
        let rotated = piece.rotated(clockwise: clockwise)
        let kicks = wallKickOffsets(
            kind: piece.kind,
            from: fromRotation,
            to: rotated.rotationIndex
        )

        if let validPiece = kicks
            .map({ rotated.moved(x: $0.x, y: $0.y) })
            .first(where: isValid) {
            activePiece = validPiece
        }
    }

    /// Super Rotation Systemのウォールキックです。
    /// 盤面は下方向が+yなので、SRSのy座標を反転して定義しています。
    private func wallKickOffsets(
        kind: TetrominoKind,
        from: Int,
        to: Int
    ) -> [GridPoint] {
        if kind == .o {
            return [GridPoint(x: 0, y: 0)]
        }

        if kind == .i {
            switch (from, to) {
            case (0, 1): return points((0, 0), (-2, 0), (1, 0), (-2, 1), (1, -2))
            case (1, 0): return points((0, 0), (2, 0), (-1, 0), (2, -1), (-1, 2))
            case (1, 2): return points((0, 0), (-1, 0), (2, 0), (-1, -2), (2, 1))
            case (2, 1): return points((0, 0), (1, 0), (-2, 0), (1, 2), (-2, -1))
            case (2, 3): return points((0, 0), (2, 0), (-1, 0), (2, -1), (-1, 2))
            case (3, 2): return points((0, 0), (-2, 0), (1, 0), (-2, 1), (1, -2))
            case (3, 0): return points((0, 0), (1, 0), (-2, 0), (1, 2), (-2, -1))
            case (0, 3): return points((0, 0), (-1, 0), (2, 0), (-1, -2), (2, 1))
            default: return [GridPoint(x: 0, y: 0)]
            }
        }

        switch (from, to) {
        case (0, 1): return points((0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2))
        case (1, 0): return points((0, 0), (1, 0), (1, 1), (0, -2), (1, -2))
        case (1, 2): return points((0, 0), (1, 0), (1, 1), (0, -2), (1, -2))
        case (2, 1): return points((0, 0), (-1, 0), (-1, -1), (0, 2), (-1, 2))
        case (2, 3): return points((0, 0), (1, 0), (1, -1), (0, 2), (1, 2))
        case (3, 2): return points((0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2))
        case (3, 0): return points((0, 0), (-1, 0), (-1, 1), (0, -2), (-1, -2))
        case (0, 3): return points((0, 0), (1, 0), (1, -1), (0, 2), (1, 2))
        default: return [GridPoint(x: 0, y: 0)]
        }
    }

    private func points(_ values: (Int, Int)...) -> [GridPoint] {
        values.map { GridPoint(x: $0.0, y: $0.1) }
    }

    private mutating func hold() {
        guard phase == .running, canHold, let current = activePiece else { return }
        canHold = false

        if let heldKind {
            self.heldKind = current.kind
            activePiece = makePiece(kind: heldKind)

            if let activePiece, !isValid(activePiece) {
                phase = .gameOver
            }
        } else {
            heldKind = current.kind
            spawnPiece()
        }
    }

    private func isValid(_ piece: ActivePiece) -> Bool {
        piece.blocks.allSatisfy { block in
            guard (0..<Self.columns).contains(block.x),
                  block.y < Self.rows else {
                return false
            }

            return block.y < 0 || board[block.y][block.x] == nil
        }
    }

    private mutating func lockPiece() {
        guard let piece = activePiece else { return }

        for block in piece.blocks where block.y >= 0 {
            board[block.y][block.x] = piece.kind
        }

        clearCompletedLines()
        canHold = true
        spawnPiece()
    }

    private mutating func clearCompletedLines() {
        let remainingRows = board.filter { row in
            row.contains(where: { $0 == nil })
        }
        let removedCount = Self.rows - remainingRows.count
        guard removedCount > 0 else { return }

        let newRows = Array(
            repeating: Array<TetrominoKind?>(
                repeating: nil,
                count: Self.columns
            ),
            count: removedCount
        )
        board = newRows + remainingRows
        clearedLines += removedCount

        let baseScore = [0, 100, 300, 500, 800][removedCount]
        score += baseScore * level
    }

    private mutating func spawnPiece() {
        let piece = makePiece(kind: nextKind)
        nextKind = takeFromBag()
        activePiece = piece

        if !isValid(piece) {
            phase = .gameOver
        }
    }

    private func makePiece(kind: TetrominoKind) -> ActivePiece {
        ActivePiece(kind: kind, origin: Self.spawnOrigin)
    }

    private mutating func takeFromBag() -> TetrominoKind {
        if bag.isEmpty {
            bag = TetrominoKind.allCases.shuffled()
        }
        return bag.removeLast()
    }

    private static var spawnOrigin: GridPoint {
        GridPoint(x: (columns - 4) / 2, y: 0)
    }

    private static func emptyBoard() -> [[TetrominoKind?]] {
        Array(
            repeating: Array(repeating: nil, count: columns),
            count: rows
        )
    }
}

enum GamePhase: Hashable {
    case running
    case paused
    case gameOver
}

/// Viewやゲームループで発生する「出来事」です。
enum GameAction {
    case newGame
    case togglePause
    case pause
    case tick
    case moveLeft
    case moveRight
    case softDrop
    case hardDrop
    case rotate(clockwise: Bool)
    case hold
}
