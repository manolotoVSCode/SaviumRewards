import Foundation

/// Codificación de códigos lineales en módulos (true = barra). Se usa para EAN-13, EAN-8, UPC-A y Code 39;
/// Code 128 y los códigos 2D se generan con Core Image en la app.
public enum Barras {
    private static let l = ["0001101", "0011001", "0010011", "0111101", "0100011",
                            "0110001", "0101111", "0111011", "0110111", "0001011"]
    private static let paridad = ["LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
                                  "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"]
    private static func r(_ d: Int) -> String { String(l[d].map { $0 == "0" ? "1" : "0" }) }
    private static func g(_ d: Int) -> String { String(r(d).reversed()) }

    /// Patrones de Code 39: 9 elementos (barra, espacio, …), W = ancho, N = estrecho.
    private static let code39: [Character: String] = [
        "0": "NNNWWNWNN", "1": "WNNWNNNNW", "2": "NNWWNNNNW", "3": "WNWWNNNNN", "4": "NNNWWNNNW",
        "5": "WNNWWNNNN", "6": "NNWWWNNNN", "7": "NNNWNNWNW", "8": "WNNWNNWNN", "9": "NNWWNNWNN",
        "A": "WNNNNWNNW", "B": "NNWNNWNNW", "C": "WNWNNWNNN", "D": "NNNNWWNNW", "E": "WNNNWWNNN",
        "F": "NNWNWWNNN", "G": "NNNNNWWNW", "H": "WNNNNWWNN", "I": "NNWNNWWNN", "J": "NNNNWWWNN",
        "K": "WNNNNNNWW", "L": "NNWNNNNWW", "M": "WNWNNNNWN", "N": "NNNNWNNWW", "O": "WNNNWNNWN",
        "P": "NNWNWNNWN", "Q": "NNNNNNWWW", "R": "WNNNNNWWN", "S": "NNWNNNWWN", "T": "NNNNWNWWN",
        "U": "WWNNNNNNW", "V": "NWWNNNNNW", "W": "WWWNNNNNN", "X": "NWNNWNNNW", "Y": "WWNNWNNNN",
        "Z": "NWWNWNNNN", "-": "NWNNNNWNW", ".": "WWNNNNWNN", " ": "NWWNNNWNN", "$": "NWNWNWNNN",
        "/": "NWNWNNNWN", "+": "NWNNNWNWN", "%": "NNNWNWNWN", "*": "NWNNWNWNN",
    ]

    public static func modulos(_ bruto: String, tipo: TipoCodigo) -> [Bool]? {
        let valor = Codigos.normalizar(bruto, tipo: tipo)
        guard Codigos.validar(valor, tipo: tipo) == .valido else { return nil }
        let texto: String?
        switch tipo {
        case .ean13: texto = ean13(valor)
        case .upca: texto = ean13("0" + valor)
        case .ean8: texto = ean8(valor)
        case .code39: texto = code39(valor)
        default: texto = nil
        }
        return texto.map { $0.map { $0 == "1" } }
    }

    private static func digitos(_ s: String) -> [Int] { s.map { Int(String($0))! } }

    private static func ean13(_ valor: String) -> String {
        let d = digitos(valor)
        let p = Array(paridad[d[0]])
        var s = "101"
        for i in 1...6 { s += p[i - 1] == "L" ? l[d[i]] : g(d[i]) }
        s += "01010"
        for i in 7...12 { s += r(d[i]) }
        return s + "101"
    }

    private static func ean8(_ valor: String) -> String {
        let d = digitos(valor)
        var s = "101"
        for i in 0...3 { s += l[d[i]] }
        s += "01010"
        for i in 4...7 { s += r(d[i]) }
        return s + "101"
    }

    private static func code39(_ valor: String) -> String {
        let caracteres = ["*"] + valor.map { String($0) } + ["*"]
        return caracteres.map { c in
            code39[Character(c)]!.enumerated().map { i, e in
                String(repeating: i.isMultiple(of: 2) ? "1" : "0", count: e == "W" ? 3 : 1)
            }.joined()
        }.joined(separator: "0")
    }
}
