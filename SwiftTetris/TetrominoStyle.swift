import SwiftUI

extension TetrominoKind {
    var color: Color {
        switch self {
        case .i: .cyan
        case .o: .yellow
        case .t: .purple
        case .s: .green
        case .z: .red
        case .j: .blue
        case .l: .orange
        }
    }
}
