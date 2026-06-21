import Foundation
import Observation

nonisolated enum GamePhase: Equatable, Sendable {
    case running
    case paused
    case gameOver
}

/// UIからゲームへ送る操作です。
/// `Sendable`な値として表すことで、actor境界を安全に越えられます。
nonisolated enum GameCommand: Sendable {
    case tick
    case newGame
    case togglePause
    case pause
    case moveLeft
    case moveRight
    case softDrop
    case hardDrop
    case rotate(clockwise: Bool)
    case hold
}

/// actor内の状態をUIへ渡す、変更不可能なスナップショットです。
nonisolated enum BoardMetrics {
    static let columns = 10
    static let rows = 20
}

nonisolated struct GameSnapshot: Sendable {
    let board: [[TetrominoKind?]]
    let activePiece: ActivePiece?
    let ghostBlocks: [GridPoint]
    let nextKind: TetrominoKind
    let heldKind: TetrominoKind?
    let score: Int
    let clearedLines: Int
    let phase: GamePhase

    var level: Int {
        clearedLines / 10 + 1
    }

    static let empty = GameSnapshot(
        board: Array(
            repeating: Array(
                repeating: nil,
                count: GameEngine.columns
            ),
            count: GameEngine.rows
        ),
        activePiece: nil,
        ghostBlocks: [],
        nextKind: .i,
        heldKind: nil,
        score: 0,
        clearedLines: 0,
        phase: .running
    )
}

/// SwiftUIとactorの橋渡しを行う、MainActor上の表示モデルです。
///
/// UI操作は`AsyncStream`へ送り、`GameSimulation`から届くスナップショットを
/// Observationが監視できるプロパティへ反映します。
@MainActor
@Observable
final class GameEngine {
    nonisolated static let columns = BoardMetrics.columns
    nonisolated static let rows = BoardMetrics.rows

    private(set) var board = GameSnapshot.empty.board
    private(set) var activePiece: ActivePiece?
    private(set) var ghostBlocks: [GridPoint] = []
    private(set) var nextKind: TetrominoKind = .i
    private(set) var heldKind: TetrominoKind?
    private(set) var score = 0
    private(set) var clearedLines = 0
    private(set) var phase: GamePhase = .running

    @ObservationIgnored private let simulation = GameSimulation()
    @ObservationIgnored private var commandContinuation:
        AsyncStream<GameCommand>.Continuation?
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    var level: Int {
        clearedLines / 10 + 1
    }

    func startLoop() {
        guard observationTask == nil else { return }

        let (commands, continuation) = AsyncStream.makeStream(
            of: GameCommand.self,
            bufferingPolicy: .bufferingNewest(32)
        )
        commandContinuation = continuation

        observationTask = Task { [weak self, simulation] in
            let snapshots = await simulation.snapshots(commands: commands)

            for await snapshot in snapshots {
                guard let self else { return }
                apply(snapshot)
            }
        }
    }

    func stopLoop() {
        commandContinuation?.finish()
        commandContinuation = nil
        observationTask?.cancel()
        observationTask = nil
    }

    func newGame() {
        send(.newGame)
    }

    func togglePause() {
        send(.togglePause)
    }

    func pause() {
        send(.pause)
    }

    func moveLeft() {
        send(.moveLeft)
    }

    func moveRight() {
        send(.moveRight)
    }

    func softDrop() {
        send(.softDrop)
    }

    func hardDrop() {
        send(.hardDrop)
    }

    func rotate(clockwise: Bool = true) {
        send(.rotate(clockwise: clockwise))
    }

    func hold() {
        send(.hold)
    }

    func settledKind(at point: GridPoint) -> TetrominoKind? {
        guard (0..<Self.columns).contains(point.x),
              (0..<Self.rows).contains(point.y) else {
            return nil
        }
        return board[point.y][point.x]
    }

    private func send(_ command: GameCommand) {
        commandContinuation?.yield(command)
    }

    private func apply(_ snapshot: GameSnapshot) {
        board = snapshot.board
        activePiece = snapshot.activePiece
        ghostBlocks = snapshot.ghostBlocks
        nextKind = snapshot.nextKind
        heldKind = snapshot.heldKind
        score = snapshot.score
        clearedLines = snapshot.clearedLines
        phase = snapshot.phase
    }
}
