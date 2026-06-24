import SwiftUI

struct ContentView: View {
    @State private var game = GameEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.11, green: 0.05, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                if proxy.size.width > 700 {
                    wideLayout
                } else {
                    compactLayout
                }
            }
            .padding()
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .task(id: game.tickConfiguration) {
            let configuration = game.tickConfiguration
            await game.runTickSequence(for: configuration)
        }
        .onDisappear {
            game.stopLoop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                game.pause()
            }
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 12) {
            header

            HStack {
                PiecePreviewView(title: "HOLD", kind: game.heldKind)
                Spacer()
                PiecePreviewView(title: "NEXT", kind: game.nextKind)
            }

            board
                .frame(maxHeight: .infinity)

            controls(showsStats: true)
        }
    }

    private var wideLayout: some View {
        HStack(spacing: 24) {
            VStack(spacing: 16) {
                PiecePreviewView(title: "HOLD", kind: game.heldKind)
                Button("ホールド", systemImage: "square.stack.3d.up") {
                    game.hold()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("c", modifiers: [])
            }
            .frame(width: 130)

            VStack(spacing: 14) {
                header
                board
                    .frame(maxHeight: .infinity)
                controls(showsStats: false)
            }

            VStack(spacing: 16) {
                PiecePreviewView(title: "NEXT", kind: game.nextKind)
                stats
            }
            .frame(width: 150)
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SWIFT")
                    .foregroundStyle(.cyan)
                + Text(" TETRIS")
                    .foregroundStyle(.white)
                Text("SwiftUI + Observation + Concurrency")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.title2.bold())

            Spacer()

            if game.phase == .gameOver {
                Button("もう一度", systemImage: "arrow.clockwise") {
                    game.newGame()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    game.togglePause()
                } label: {
                    Image(systemName: game.phase == .paused ? "play.fill" : "pause.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(game.phase == .paused ? "再開" : "一時停止")
                .keyboardShortcut("p", modifiers: [])
            }
        }
    }

    private var board: some View {
        GameBoardView(game: game)
            .overlay {
                if game.phase != .running {
                    statusOverlay
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                game.rotate()
            }
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded(handleDrag)
            )
    }

    private var statusOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.black.opacity(0.68))

            VStack(spacing: 12) {
                Image(
                    systemName: game.phase == .gameOver
                        ? "exclamationmark.triangle.fill"
                        : "pause.circle.fill"
                )
                .font(.system(size: 42))
                .foregroundStyle(game.phase == .gameOver ? .orange : .cyan)

                Text(game.phase == .gameOver ? "GAME OVER" : "PAUSED")
                    .font(.title.bold())

                if game.phase == .gameOver {
                    Button("ニューゲーム") {
                        game.newGame()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("再開") {
                        game.togglePause()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var stats: some View {
        VStack(spacing: 12) {
            StatView(label: "SCORE", value: game.score.formatted())
            StatView(label: "LINES", value: game.clearedLines.formatted())
            StatView(label: "LEVEL", value: game.level.formatted())
        }
    }

    private func controls(showsStats: Bool) -> some View {
        VStack(spacing: 10) {
            if showsStats {
                HStack {
                    StatView(label: "SCORE", value: game.score.formatted())
                    StatView(label: "LINES", value: game.clearedLines.formatted())
                    StatView(label: "LEVEL", value: game.level.formatted())
                }
            }

            HStack(spacing: 12) {
                ControlButton(systemName: "square.stack.3d.up", label: "HOLD") {
                    game.hold()
                }
                .keyboardShortcut("c", modifiers: [])

                ControlButton(systemName: "arrow.left", label: "左") {
                    game.moveLeft()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                ControlButton(systemName: "rotate.right", label: "回転") {
                    game.rotate()
                }
                .keyboardShortcut(.upArrow, modifiers: [])

                ControlButton(systemName: "arrow.right", label: "右") {
                    game.moveRight()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                ControlButton(systemName: "arrow.down.to.line", label: "落下") {
                    game.hardDrop()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }

    private func handleDrag(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        if abs(horizontal) > abs(vertical) {
            horizontal < 0 ? game.moveLeft() : game.moveRight()
        } else if vertical > 70 {
            game.hardDrop()
        } else if vertical > 0 {
            game.softDrop()
        } else {
            game.rotate()
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
                .font(.title3.monospacedDigit().bold())
                .contentTransition(.numericText())
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
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}

#Preview {
    ContentView()
}
