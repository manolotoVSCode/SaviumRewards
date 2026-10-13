import Foundation

/// Validación de los contenidos de cada tipo de código. Misma especificación que web/src/lib/codigos.ts
/// (casos comunes en shared/fixtures/codigos.json).
public enum Codigos {
    public enum Motivo: String, Sendable {
        case vacio, longitud, caracteres, digitoControl, noAdmiteValor, demasiadoLargo
    }

    public enum Resultado: Equatable, Sendable {
        case valido
        case invalido(Motivo)
        public var motivo: Motivo? { if case .invalido(let m) = self { m } else { nil } }
    }

    public static let longitudMaxima = 512
    /// Juego de caracteres de Code 39 (sin el asterisco, que es el delimitador).
    static let code39 = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%")

    /// Quita espacios sobrantes; en los numéricos, todos los espacios.
    public static func normalizar(_ valor: String, tipo: TipoCodigo) -> String {
        let recortado = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        switch tipo {
        case .ean13, .ean8, .upca: return recortado.filter { !$0.isWhitespace }
        default: return recortado
        }
    }

    public static func validar(_ bruto: String, tipo: TipoCodigo) -> Resultado {
        let valor = normalizar(bruto, tipo: tipo)
        if tipo == .ninguno { return valor.isEmpty ? .valido : .invalido(.noAdmiteValor) }
        if valor.isEmpty { return .invalido(.vacio) }
        // Code points, como char_length de Postgres y la web (no caracteres visibles).
        if valor.unicodeScalars.count > longitudMaxima { return .invalido(.demasiadoLargo) }
        switch tipo {
        case .ean13: return numerico(valor, longitud: 13)
        case .ean8: return numerico(valor, longitud: 8)
        case .upca: return numerico(valor, longitud: 12)
        case .code39: return valor.allSatisfy(code39.contains) ? .valido : .invalido(.caracteres)
        case .code128:
            // ASCII imprimible (32…126).
            return valor.unicodeScalars.allSatisfy { (32...126).contains($0.value) } ? .valido : .invalido(.caracteres)
        case .qr, .pdf417, .aztec, .ninguno:
            return .valido
        }
    }

    private static func numerico(_ valor: String, longitud: Int) -> Resultado {
        guard valor.allSatisfy(\.isASCIIDigit) else { return .invalido(.caracteres) }
        guard valor.count == longitud else { return .invalido(.longitud) }
        let control = Int(String(valor.last!))!
        return digitoControl(String(valor.dropLast())) == control ? .valido : .invalido(.digitoControl)
    }

    /// Dígito de control GS1 (EAN/UPC): pesos 3 y 1 alternos empezando por la derecha.
    public static func digitoControl(_ digitos: String) -> Int? {
        guard !digitos.isEmpty, digitos.allSatisfy(\.isASCIIDigit) else { return nil }
        var suma = 0
        for (i, c) in digitos.reversed().enumerated() {
            suma += Int(String(c))! * (i.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - suma % 10) % 10
    }

    /// Si falta solo el dígito de control, devuelve el código completo.
    public static func completar(_ bruto: String, tipo: TipoCodigo) -> String? {
        let valor = normalizar(bruto.filter { !$0.isWhitespace }, tipo: tipo)
        let longitud: Int
        switch tipo {
        case .ean13: longitud = 13
        case .ean8: longitud = 8
        case .upca: longitud = 12
        default: return nil
        }
        guard valor.count == longitud - 1, let d = digitoControl(valor) else { return nil }
        return valor + String(d)
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
