import Foundation

public struct TotalUnidad: Equatable, Hashable, Sendable {
    public let unidad: String
    public let total: Int64
    public init(unidad: String, total: Int64) { self.unidad = unidad; self.total = total }
}

public enum Totales {
    /// Suma los saldos por unidad («puntos», «millas», «Avios»…). Nunca mezcla unidades distintas;
    /// agrupa sin distinguir mayúsculas, acentos ni espacios. Ordenado de mayor a menor total.
    public static func porUnidad(_ tarjetas: [Tarjeta], programas: [UUID: Programa]) -> [TotalUnidad] {
        var totales: [String: (unidad: String, total: Int64, orden: Int)] = [:]
        for t in tarjetas where !t.borrado {
            guard let saldo = t.saldo else { continue }
            let unidad = t.unidadEfectiva(t.programaId.flatMap { programas[$0] })
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let clave = unidad.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            if let actual = totales[clave] {
                totales[clave] = (actual.unidad, actual.total.addingReportingOverflow(saldo).overflow ? .max : actual.total + saldo, actual.orden)
            } else {
                totales[clave] = (unidad, saldo, totales.count)
            }
        }
        return totales.values
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.orden < $1.orden }
            .map { TotalUnidad(unidad: $0.unidad, total: $0.total) }
    }
}
