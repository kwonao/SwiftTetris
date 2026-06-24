import Foundation

/// ゲーム状態を排他的に所有するactorです。
///
/// ユーザー入力と自動落下tickは`GameEventStreams.merge`で1つのイベント列に合成され、
/// 状態変更は必ずこのactor内で直列化されます。そのため、盤面を書き換えている途中に
/// 別操作が割り込むことはありません。
actor GameSimulation {
    private var board: [[TetrominoKind?]]
    private var activePiece: ActivePiece?
    private var nextKind: TetrominoKind = .i
    private var heldKind: TetrominoKind?
    private var score = 0
    private var clearedLines = 0
    private var phase: GamePhase = .running
    private var gameID = 0
    private var bag: [TetrominoKind] = []
    private var canHold = true

    init() {
        var initialBag = TetrominoKind.allCases.shuffled()
        let firstKind = initialBag.removeLast()
        let secondKind = initialBag.removeLast()

        board = Self.emptyBoard()
        bag = initialBag
        nextKind = secondKind
        activePiece = ActivePiece(
            kind: firstKind,
            origin: GridPoint(x: (BoardMetrics.columns - 4) / 2, y: 0)
        )
    }

    /// 合成済みのイベント列を`for await`で処理し、
    /// 状態変化を`AsyncStream`としてUIへ公開します。
    func snapshots(
        events: AsyncStream<GameEvent>
    ) -> AsyncStream<GameSnapshot> {
        let initialSnapshot = makeSnapshot()

        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.yield(initialSnapshot)

            let producer = Task {
                for await event in events {
                    guard !Task.isCancelled else { break }
                    await self.process(event)
                    continuation.yield(await self.makeSnapshot())
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                producer.cancel()
            }
        }
    }

    private var level: Int {
        clearedLines / 10 + 1
    }

    private func process(_ event: GameEvent) {
        switch event {
        case .tick:
            tick()
        case let .input(input):
            process(input)
        }
    }

    private func process(_ input: GameInput) {
        switch input {
        case .newGame:
            newGame()
        case .togglePause:
            togglePause()
        case .pause:
            pause()
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

    private func newGame() {
        board = Self.emptyBoard()
        activePiece = nil
        heldKind = nil
        score = 0
        clearedLines = 0
        phase = .running
        gameID += 1
        bag = TetrominoKind.allCases.shuffled()
        nextKind = takeFromBag()
        canHold = true
        spawnPiece()
    }

    private func togglePause() {
        switch phase {
        case .running:
            phase = .paused
        case .paused:
            phase = .running
        case .gameOver:
            break
        }
    }

    private func pause() {
        if phase == .running {
            phase = .paused
        }
    }

    private func tick() {
        guard phase == .running, let piece = activePiece else { return }
        let candidate = piece.moved(y: 1)

        if isValid(candidate) {
            activePiece = candidate
        } else {
            lockPiece()
        }
    }

    private func moveActivePiece(x: Int) {
        guard phase == .running, let piece = activePiece else { return }
        let candidate = piece.moved(x: x)
        if isValid(candidate) {
            activePiece = candidate
        }
    }

    private func softDrop() {
        guard phase == .running, let piece = activePiece else { return }
        let candidate = piece.moved(y: 1)

        if isValid(candidate) {
            activePiece = candidate
            score += 1
        } else {
            lockPiece()
        }
    }

    private func hardDrop() {
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

    private func rotate(clockwise: Bool) {
        guard phase == .running, let piece = activePiece else { return }
        let rotated = piece.rotated(clockwise: clockwise)

        let kicks = [
            GridPoint(x: 0, y: 0),
            GridPoint(x: -1, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: -2, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 0, y: -1)
        ]

        if let validPiece = kicks
            .map({ rotated.moved(x: $0.x, y: $0.y) })
            .first(where: isValid) {
            activePiece = validPiece
        }
    }

    private func hold() {
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
            guard (0..<BoardMetrics.columns).contains(block.x),
                  block.y < BoardMetrics.rows else {
                return false
            }

            return block.y < 0 || board[block.y][block.x] == nil
        }
    }

    private func lockPiece() {
        guard let piece = activePiece else { return }

        for block in piece.blocks where block.y >= 0 {
            board[block.y][block.x] = piece.kind
        }

        clearCompletedLines()
        canHold = true
        spawnPiece()
    }

    private func clearCompletedLines() {
        let remainingRows = board.filter { row in
            row.contains(where: { $0 == nil })
        }
        let removedCount = BoardMetrics.rows - remainingRows.count
        guard removedCount > 0 else { return }

        let newRows = Array(
            repeating: Array<TetrominoKind?>(
                repeating: nil,
                count: BoardMetrics.columns
            ),
            count: removedCount
        )
        board = newRows + remainingRows
        clearedLines += removedCount

        let baseScore = [0, 100, 300, 500, 800][removedCount]
        score += baseScore * level
    }

    private func spawnPiece() {
        let piece = makePiece(kind: nextKind)
        nextKind = takeFromBag()
        activePiece = piece

        if !isValid(piece) {
            phase = .gameOver
        }
    }

    private func makePiece(kind: TetrominoKind) -> ActivePiece {
        ActivePiece(
            kind: kind,
            origin: GridPoint(x: (BoardMetrics.columns - 4) / 2, y: 0)
        )
    }

    private func takeFromBag() -> TetrominoKind {
        if bag.isEmpty {
            bag = TetrominoKind.allCases.shuffled()
        }
        return bag.removeLast()
    }

    private func makeSnapshot() -> GameSnapshot {
        GameSnapshot(
            board: board,
            activePiece: activePiece,
            ghostBlocks: ghostBlocks,
            nextKind: nextKind,
            heldKind: heldKind,
            score: score,
            clearedLines: clearedLines,
            phase: phase,
            gameID: gameID
        )
    }

    private var ghostBlocks: [GridPoint] {
        guard var ghost = activePiece else { return [] }
        while isValid(ghost.moved(y: 1)) {
            ghost = ghost.moved(y: 1)
        }
        return ghost.blocks
    }

    private static func emptyBoard() -> [[TetrominoKind?]] {
        Array(
            repeating: Array(
                repeating: nil,
                count: BoardMetrics.columns
            ),
            count: BoardMetrics.rows
        )
    }
}
