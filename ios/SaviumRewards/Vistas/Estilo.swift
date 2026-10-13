import SwiftUI
import RewardsCore

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// «#RRGGBB»; si no es válido, el verde Savium suave.
    init(hexTexto: String) {
        let limpio = hexTexto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        self.init(hex: UInt32(limpio, radix: 16).flatMap { limpio.count == 6 ? $0 : nil } ?? 0x4F8248)
    }

    /// Versión más clara u oscura (para los degradados de las tarjetas).
    func mezclado(con otro: Color, _ cantidad: Double) -> Color {
        Color(UIColor(self).mezclado(con: UIColor(otro), cantidad))
    }
}

extension UIColor {
    func mezclado(con otro: UIColor, _ t: Double) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otro.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(t)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}

enum Paleta {
    static let verdeSavium = Color(hex: 0x239005)

    static func degradado(_ hex: String) -> LinearGradient {
        let base = Color(hexTexto: hex)
        return LinearGradient(colors: [base.mezclado(con: .white, 0.18), base.mezclado(con: .black, 0.12)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Colores para «Otro programa».
    static let propios = ["#4F8248", "#4F837F", "#5B7397", "#726A98", "#86698A", "#A56C7E", "#A87B5A", "#A46F62", "#968551", "#676E77"]
}

extension TipoPrograma {
    var simbolo: String {
        switch self {
        case .tarjetaCredito: "creditcard.fill"
        case .aerolinea: "airplane"
        case .hotel: "bed.double.fill"
        case .comercio: "cart.fill"
        }
    }

    var nombre: LocalizedStringResource {
        switch self {
        case .tarjetaCredito: "Tarjetas de crédito"
        case .aerolinea: "Aerolíneas"
        case .hotel: "Hoteles"
        case .comercio: "Comercios"
        }
    }
}

extension TipoCodigo {
    var nombre: LocalizedStringResource {
        switch self {
        case .qr: "QR"
        case .code128: "Code 128"
        case .ean13: "EAN-13"
        case .ean8: "EAN-8"
        case .upca: "UPC-A"
        case .code39: "Code 39"
        case .pdf417: "PDF417"
        case .aztec: "Aztec"
        case .ninguno: "Sin código"
        }
    }
}

extension Codigos.Motivo {
    var texto: LocalizedStringResource {
        switch self {
        case .vacio: "Escribe o escanea el código."
        case .longitud: "El número no tiene la longitud de este tipo de código."
        case .caracteres: "Tiene caracteres que este tipo de código no admite."
        case .digitoControl: "El último dígito no cuadra: revisa el número."
        case .noAdmiteValor: "Sin código no lleva contenido."
        case .demasiadoLargo: "Es demasiado largo."
        }
    }
}

/// Pulsación con leve encogimiento, como las tarjetas de Wallet.
struct EstiloTarjeta: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
