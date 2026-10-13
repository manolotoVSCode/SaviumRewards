import Foundation

/// Codificación JSON para hablar con PostgREST: claves en snake_case y fechas ISO 8601
/// (Postgres devuelve microsegundos, «2026-10-13T19:55:25.731234+00:00»).
public enum Servidor {
    public static func fecha(_ texto: String) -> Date? {
        // Se recortan las fracciones a milisegundos, que es lo que entiende el formato ISO 8601 de Foundation.
        var t = texto
        if let punto = t.firstIndex(of: "."),
           let fin = t[punto...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let fraccion = t[t.index(after: punto)..<fin]
            t.replaceSubrange(t.index(after: punto)..<fin, with: String((fraccion + "000").prefix(3)))
        } else if let fin = t.lastIndex(where: { $0 == "+" || $0 == "Z" }) ?? t.lastIndex(of: "-"), fin > t.index(t.startIndex, offsetBy: 10) {
            t.insert(contentsOf: ".000", at: fin)
        }
        return try? Date(t, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    public static func texto(_ fecha: Date) -> String {
        fecha.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    public static let decodificador: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            guard let f = fecha(s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Fecha no válida: \(s)")
            }
            return f
        }
        return d
    }()

    public static let codificador: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .custom { fecha, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(texto(fecha))
        }
        return e
    }()
}
