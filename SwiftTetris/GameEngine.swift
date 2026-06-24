import Foundation
import Observation

nonisolated enum GamePhase: Hashable, Sendable {
    case running
    case paused
    case gameOver
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
    let gameID: Int

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
        phase: .running,
        gameID: 0
    )
}

/// SwiftUIとactorの橋渡しを行う、MainActor上の表示モデルです。
///
/// UI入力と時間tickをそれぞれ`AsyncStream`として受け取り、`GameSimulation`から届く
/// スナップショットをObservationが監視できるプロパティへ反映します。
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
    private(set) var gameID = 0

    @ObservationIgnored private let simulation = GameSimulation()
    @ObservationIgnored private var inputContinuation:
        AsyncStream<GameInput>.Continuation?
    @ObservationIgnored private var tickContinuation:
        AsyncStream<GameTick>.Continuation?
    @ObservationIgnored private var observationTask: Task<Void, Never>?

    var level: Int {
        clearedLines / 10 + 1
    }

    var tickConfiguration: GameTickConfiguration {
        GameTickConfiguration(level: level, phase: phase, gameID: gameID)
    }

    func startLoop() {
        guard observationTask == nil else { return }

        let (inputs, inputContinuation) = AsyncStream.makeStream(
            of: GameInput.self,
            bufferingPolicy: .bufferingNewest(32)
        )
        let (ticks, tickContinuation) = AsyncStream.makeStream(
            of: GameTick.self,
            bufferingPolicy: .bufferingNewest(8)
        )
        self.inputContinuation = inputContinuation
        self.tickContinuation = tickContinuation

        let events = GameEventStreams.merge(ticks: ticks, inputs: inputs)

        observationTask = Task { [weak self, simulation] in
            let snapshots = await simulation.snapshots(events: events)

            for await snapshot in snapshots {
                guard let self else { return }
                apply(snapshot)
            }
        }
    }

    func stopLoop() {
        inputContinuation?.finish()
        inputContinuation = nil
        tickContinuation?.finish()
        tickContinuation = nil
        observationTask?.cancel()
        observationTask = nil
    }

    func runTickSequence(for configuration: GameTickConfiguration) async {
        startLoop()

        guard configuration.isRunning else { return }

        let ticks = GameTickSequence(interval: configuration.interval)
        for await tick in ticks {
            guard !Task.isCancelled else { return }
            tickContinuation?.yield(tick)
        }
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

    private func send(_ input: GameInput) {
        inputContinuation?.yield(input)
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
        gameID = snapshot.gameID
    }
}
