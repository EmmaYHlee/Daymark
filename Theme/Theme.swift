import SwiftUI

extension Color {
    init(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(.sRGB,
                  red: Double((int >> 16) & 0xFF) / 255,
                  green: Double((int >> 8) & 0xFF) / 255,
                  blue: Double(int & 0xFF) / 255,
                  opacity: 1)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System Default"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct GradientTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let light: [String]
    let dark: [String]
    let accentLight: String   // deep, saturated: used for calendar check marks (white text on top)
    let accentDark: String
    let darkTextInLight: Bool // pale gradients get dark text in light mode

    func gradient(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: (scheme == .dark ? dark : light).map(Color.init(hex:)),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    func accent(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? accentDark : accentLight) }
    func onGradient(_ scheme: ColorScheme) -> Color {
        (scheme == .light && darkTextInLight) ? Color(hex: "1F2430") : .white
    }

    static let all: [GradientTheme] = [
        GradientTheme(id: "lavender", name: "Lavender Dream", light: ["CDB8FF", "9068E8"], dark: ["5B4796", "362A6B"],
                      accentLight: "7A56D6", accentDark: "B9A2FF", darkTextInLight: true),
        GradientTheme(id: "ocean", name: "Ocean Breeze", light: ["6BB8F2", "1D4FB8"], dark: ["2B6CB0", "14306B"],
                      accentLight: "1D5FD0", accentDark: "7DB8FF", darkTextInLight: false),
        GradientTheme(id: "peach", name: "Peach Glow", light: ["FFD3B8", "FFA9C0"], dark: ["A6604E", "8A3E5E"],
                      accentLight: "D9647C", accentDark: "FFA3B5", darkTextInLight: true),
        GradientTheme(id: "sage", name: "Sage Garden", light: ["B7D8B5", "8FD9C0"], dark: ["3F6B55", "2C5A52"],
                      accentLight: "3F8F6B", accentDark: "8FD9B5", darkTextInLight: true),
        GradientTheme(id: "sunset", name: "Sunset", light: ["FF9A5A", "E8507A"], dark: ["B5532D", "8C2B4E"],
                      accentLight: "D9455F", accentDark: "FF8A9E", darkTextInLight: false),
        GradientTheme(id: "midnight", name: "Midnight", light: ["2A3A7A", "4B3FB5"], dark: ["141B3D", "2C2670"],
                      accentLight: "4B3FB5", accentDark: "9A93FF", darkTextInLight: false),
        GradientTheme(id: "golden", name: "Golden Hour", light: ["FFF1CC", "F0C060"], dark: ["8A6A1F", "5E4512"],
                      accentLight: "B8860B", accentDark: "F0C060", darkTextInLight: true),
        GradientTheme(id: "rose", name: "Rose Quartz", light: ["E7B0BE", "C9667F"], dark: ["8A4A5C", "5E2A3E"],
                      accentLight: "B84A67", accentDark: "F0A0B8", darkTextInLight: true)
    ]

    static func theme(for id: String) -> GradientTheme { all.first { $0.id == id } ?? all[0] }
}

let goalIcons = ["sparkles", "figure.run", "dumbbell.fill", "book.fill", "drop.fill", "moon.fill",
                 "brain.head.profile", "leaf.fill", "pencil.and.outline", "heart.fill", "music.note",
                 "fork.knife", "laptopcomputer", "bicycle", "cup.and.saucer.fill", "star.fill"]
