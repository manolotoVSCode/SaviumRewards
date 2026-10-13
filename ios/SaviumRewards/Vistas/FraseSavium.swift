import SwiftUI

/// Una frase distinta cada vez que aparece, como en Savium Finanzas y Savium Share.
/// Se escribe letra a letra con un cursor que parpadea, salvo con «Reducir movimiento».
struct FraseSavium: View {
    static let frases: [LocalizedStringResource] = [
        "Contando puntos desde 2025",
        "Sumando millas desde 2025",
        "Cuidando monederos desde 2025",
        "Coleccionando estrellas desde 2025",
        "Vigilando la cartera desde 2025",
        "Ahorrando con estilo desde 2025",
        "Canjeando con cabeza desde 2025",
        "Volando con puntos desde 2025",
    ]

    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var frase = String(localized: Self.frases.randomElement()!)
    @State private var escritas = 0
    @State private var cursor = true

    var body: some View {
        let completa = reducirMovimiento || escritas >= frase.count
        HStack(spacing: 1) {
            Text(String(frase.prefix(completa ? frase.count : escritas)))
            if !completa || cursor {
                Text(verbatim: "▍").opacity(completa ? (cursor ? 0.6 : 0) : 0.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(frase)
        .task {
            guard !reducirMovimiento else { return }
            try? await Task.sleep(for: .milliseconds(500))
            while escritas < frase.count {
                escritas += 1
                try? await Task.sleep(for: .milliseconds(55))
            }
            for _ in 0..<6 {
                try? await Task.sleep(for: .milliseconds(500))
                cursor.toggle()
            }
            cursor = false
        }
    }
}
