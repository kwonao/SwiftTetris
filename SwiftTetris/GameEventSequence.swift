import Foundation

/// UIからゲームへ送る入力です。
///
/// `tick`をここに含めないのがポイントです。ユーザー操作と時間経過は発生源が違うため、
/// それぞれを別の`AsyncSequence`として扱い、後段で`GameEvent`へ合成します。
nonisolated enum GameInput: Sendable {
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

/// 自動落下を表す時間イベントです。
nonisolated struct GameTick: Sendable {
    let index: Int
}

/// actorが処理するイベントです。
///
/// `input`と`tick`を1つの列へ揃えることで、ゲーム状態の更新は
/// `for await event in events`という単一の入口に集約できます。
nonisolated enum GameEvent: Sendable {
    case input(GameInput)
    case tick(GameTick)
}

/// SwiftUIの`.task(id:)`でtick列を再生成するための設定値です。
///
/// - `level`が変わると落下間隔が変わるため、sequenceを作り直します。
/// - `phase`がpaused/gameOverになると、SwiftUIが実行中のtick taskをキャンセルします。
/// - `gameID`が変わると、同じlevelでもリスタートとして新しいsequenceを開始できます。
nonisolated struct GameTickConfiguration: Hashable, Sendable {
    let level: Int
    let phase: GamePhase
    let gameID: Int

    var isRunning: Bool {
        phase == .running
    }

    var interval: Duration {
        .milliseconds(max(90, 700 - (level - 1) * 55))
    }
}

/// 一定間隔で`GameTick`を流す`AsyncSequence`です。
///
/// `Timer`をViewに直接置かず、時間を「非同期に到着する値の列」として扱います。
/// キャンセルされると`Task.sleep`がthrowし、自然にsequenceが終了します。
nonisolated struct GameTickSequence: AsyncSequence, Sendable {
    typealias Element = GameTick

    private let interval: Duration

    init(interval: Duration) {
        self.interval = interval
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(interval: interval)
    }

    nonisolated struct Iterator: AsyncIteratorProtocol {
        private let interval: Duration
        private var nextIndex = 0

        init(interval: Duration) {
            self.interval = interval
        }

        mutating func next() async -> GameTick? {
            do {
                try await Task.sleep(for: interval)
            } catch {
                return nil
            }

            nextIndex += 1
            return GameTick(index: nextIndex)
        }
    }
}

/// 複数のイベント列を、ゲームが処理しやすい単一の`AsyncStream<GameEvent>`へ合成します。
nonisolated enum GameEventStreams {
    static func merge(
        ticks: AsyncStream<GameTick>,
        inputs: AsyncStream<GameInput>
    ) -> AsyncStream<GameEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            let producer = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await tick in ticks {
                            guard !Task.isCancelled else { return }
                            continuation.yield(.tick(tick))
                        }
                    }

                    group.addTask {
                        for await input in inputs {
                            guard !Task.isCancelled else { return }
                            continuation.yield(.input(input))
                        }
                    }

                    await group.waitForAll()
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                producer.cancel()
            }
        }
    }
}
