import AsyncAlgorithms
import Observation

/// SwiftUIが所有する、状態とActionの窓口です。
@MainActor
@Observable
final class GameStore {
    private(set) var state = GameState()

    /// phase・ゲームが変わったときだけ`.task(id:)`を再起動します。
    var loopID: GameLoopID {
        GameLoopID(
            phase: state.phase,
            gameID: state.gameID
        )
    }

    func send(_ action: GameAction) {
        state.reduce(action)
    }

    /// 時間を非同期イベント列として受け取り、各要素をゲームのtickへ変換します。
    func runGameLoop() async {
        guard state.phase == .running else { return }
        let ticks = AsyncTimerSequence.repeating(
            every: state.tickInterval,
            tolerance: .milliseconds(5)
        )

        for await _ in ticks {
            guard state.phase == .running else { return }
            send(.tick)
        }
    }
}

struct GameLoopID: Hashable {
    let phase: GamePhase
    let gameID: Int
}
