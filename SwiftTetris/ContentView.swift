import AsyncAlgorithms
import SwiftUI

struct ContentView: View {
    @State private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > 700 {
                wideLayout
            } else {
                compactLayout
            }
        }
        .padding(10)
        .task(id: store.loopID) {
            await store.runGameLoop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                store.send(.pause)
            }
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 8) {
            header

            HStack(spacing: 8) {
                PiecePreviewView(title: "HOLD", kind: store.state.heldKind)
                PiecePreviewView(title: "NEXT", kind: store.state.nextKind)
            }

            board
                .frame(maxHeight: .infinity)

            controls(showsStats: true)
        }
    }

    private var wideLayout: some View {
        HStack(spacing: 16) {
            VStack {
                PiecePreviewView(title: "HOLD", kind: store.state.heldKind)
            }
            .frame(width: 100)

            VStack(spacing: 10) {
                header
                board
                    .frame(maxHeight: .infinity)
                controls(showsStats: false)
            }

            VStack(spacing: 12) {
                PiecePreviewView(title: "NEXT", kind: store.state.nextKind)
                stats
            }
            .frame(width: 110)
        }
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Swift Tetris")
                    .font(.title2.bold())
                Text("State → Action → Reducer → View")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.state.phase == .gameOver {
                Button {
                    store.send(.newGame)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("もう一度")
            } else {
                Button {
                    store.send(.togglePause)
                } label: {
                    Image(
                        systemName: store.state.phase == .paused
                            ? "play.fill"
                            : "pause.fill"
                    )
                }
                .buttonStyle(.glass)
                .accessibilityLabel(store.state.phase == .paused ? "再開" : "一時停止")
                .keyboardShortcut("p", modifiers: [])
            }
        }
    }

    private var board: some View {
        GameBoardView(state: store.state)
            .overlay {
                if store.state.phase != .running {
                    statusOverlay
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.send(.rotate(clockwise: true))
            }
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded(handleDrag)
            )
    }

    private var statusOverlay: some View {
        VStack(spacing: 12) {
            Label(
                store.state.phase == .gameOver ? "ゲームオーバー" : "一時停止中",
                systemImage: store.state.phase == .gameOver
                    ? "exclamationmark.triangle"
                    : "pause.circle"
            )
            .font(.title2)

            if store.state.phase == .gameOver {
                Button {
                    store.send(.newGame)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("ニューゲーム")
            } else {
                Button {
                    store.send(.togglePause)
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("再開")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var stats: some View {
        VStack(spacing: 12) {
            StatView(label: "SCORE", value: store.state.score.formatted())
            StatView(label: "LINES", value: store.state.clearedLines.formatted())
            StatView(label: "LEVEL", value: store.state.level.formatted())
        }
    }

    private func controls(showsStats: Bool) -> some View {
        VStack(spacing: 10) {
            if showsStats {
                HStack {
                    StatView(label: "SCORE", value: store.state.score.formatted())
                    StatView(label: "LINES", value: store.state.clearedLines.formatted())
                    StatView(label: "LEVEL", value: store.state.level.formatted())
                }
            }

            HStack(spacing: 8) {
                ControlButton(systemName: "square.stack.3d.up", label: "HOLD") {
                    store.send(.hold)
                }
                .keyboardShortcut("c", modifiers: [])

                ControlButton(systemName: "arrow.left", label: "左") {
                    store.send(.moveLeft)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                ControlButton(systemName: "rotate.right", label: "回転") {
                    store.send(.rotate(clockwise: true))
                }
                .keyboardShortcut(.upArrow, modifiers: [])

                ControlButton(systemName: "arrow.right", label: "右") {
                    store.send(.moveRight)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                SoftDropButton {
                    store.send(.softDrop)
                }
            }
        }
    }

    private func handleDrag(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        if abs(horizontal) > abs(vertical) {
            store.send(horizontal < 0 ? .moveLeft : .moveRight)
        } else if vertical > 70 {
            store.send(.hardDrop)
        } else if vertical > 0 {
            store.send(.softDrop)
        } else {
            store.send(.rotate(clockwise: true))
        }
    }
}

private struct StatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ControlButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}

private struct SoftDropButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("落下")
        .accessibilityHint("押している間、速く落下します")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .task(id: isPressed) {
            guard isPressed else { return }
            let repeats = AsyncTimerSequence.repeating(
                every: .milliseconds(65),
                tolerance: .milliseconds(5)
            )

            for await _ in repeats {
                guard isPressed else { return }
                action()
            }
        }
    }
}

#Preview {
    ContentView()
}
