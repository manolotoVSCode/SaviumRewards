import Foundation

public enum TipoCodigo: String, Codable, CaseIterable, Sendable {
    case qr, code128, ean13, ean8, upca, code39, pdf417, aztec, ninguno

    /// Códigos de barras de una dimensión (se dibujan como barras, no como matriz).
    public var esLineal: Bool { [.code128, .ean13, .ean8, .upca, .code39].contains(self) }
}

public enum TipoPrograma: String, Codable, CaseIterable, Sendable {
    case tarjetaCredito = "tarjeta_credito", aerolinea, hotel, comercio
}

public struct Programa: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var nombre: String
    public var tipo: TipoPrograma
    public var pais: String
    public var color: String
    public var unidad: String
    public var codigoTipo: TipoCodigo
    public var activo: Bool

    public init(id: UUID, nombre: String, tipo: TipoPrograma, pais: String, color: String, unidad: String,
                codigoTipo: TipoCodigo, activo: Bool) {
        self.id = id; self.nombre = nombre; self.tipo = tipo; self.pais = pais; self.color = color
        self.unidad = unidad; self.codigoTipo = codigoTipo; self.activo = activo
    }
}

/// Una tarjeta de fidelidad. Las fechas `saldoFecha` y `caducidad` van como «aaaa-mm-dd» (tipo date de Postgres).
public struct Tarjeta: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var userId: UUID
    public var programaId: UUID?
    public var nombre: String?
    public var color: String?
    public var unidad: String?
    public var numeroSocio: String?
    public var codigoValor: String?
    public var codigoTipo: TipoCodigo
    public var titular: String?
    public var saldo: Int64?
    public var saldoFecha: String?
    public var caducidad: String?
    public var notas: String?
    public var compartida: Bool
    public var orden: Int
    public var actualizado: Date
    public var sincronizado: Date?
    public var borrado: Bool

    public init(id: UUID = UUID(), userId: UUID, programaId: UUID? = nil, nombre: String? = nil, color: String? = nil,
                unidad: String? = nil, numeroSocio: String? = nil, codigoValor: String? = nil,
                codigoTipo: TipoCodigo = .ninguno, titular: String? = nil, saldo: Int64? = nil,
                saldoFecha: String? = nil, caducidad: String? = nil, notas: String? = nil, compartida: Bool = false,
                orden: Int = 0, actualizado: Date = .now, sincronizado: Date? = nil, borrado: Bool = false) {
        self.id = id; self.userId = userId; self.programaId = programaId; self.nombre = nombre; self.color = color
        self.unidad = unidad; self.numeroSocio = numeroSocio; self.codigoValor = codigoValor
        self.codigoTipo = codigoTipo; self.titular = titular; self.saldo = saldo; self.saldoFecha = saldoFecha
        self.caducidad = caducidad; self.notas = notas; self.compartida = compartida; self.orden = orden
        self.actualizado = actualizado; self.sincronizado = sincronizado; self.borrado = borrado
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, programaId, nombre, color, unidad, numeroSocio, codigoValor, codigoTipo, titular, saldo,
             saldoFecha, caducidad, notas, compartida, orden, actualizado, sincronizado, borrado
    }

    /// Codifica los opcionales vacíos como null explícito: así, al subir, el servidor también borra un campo
    /// que se ha vaciado (con el Codable sintetizado la clave no se envía y el valor antiguo se queda).
    /// `sincronizado` no se envía: lo pone el servidor.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(programaId, forKey: .programaId)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(color, forKey: .color)
        try c.encode(unidad, forKey: .unidad)
        try c.encode(numeroSocio, forKey: .numeroSocio)
        try c.encode(codigoValor, forKey: .codigoValor)
        try c.encode(codigoTipo, forKey: .codigoTipo)
        try c.encode(titular, forKey: .titular)
        try c.encode(saldo, forKey: .saldo)
        try c.encode(saldoFecha, forKey: .saldoFecha)
        try c.encode(caducidad, forKey: .caducidad)
        try c.encode(notas, forKey: .notas)
        try c.encode(compartida, forKey: .compartida)
        try c.encode(orden, forKey: .orden)
        try c.encode(actualizado, forKey: .actualizado)
        try c.encode(borrado, forKey: .borrado)
    }

    /// Límites de longitud del servidor (CHECK de rewards_tarjetas), en code points como char_length de Postgres.
    public var textosConLimite: [(valor: String?, maximo: Int)] {
        [(nombre, 60), (unidad, 20), (numeroSocio, 64), (titular, 60), (notas, 1000)]
    }

    /// true si la tarjeta cumple las restricciones del servidor (para no bloquear la sincronización).
    public var cumpleLimites: Bool {
        guard programaId != nil || !(nombre ?? "").isEmpty else { return false }
        guard (saldo ?? 0) >= 0, (saldo ?? 0) <= Self.saldoMaximo else { return false }
        guard (codigoTipo == .ninguno) == (codigoValor == nil) else { return false }
        if let codigoValor, Codigos.validar(codigoValor, tipo: codigoTipo) != .valido { return false }
        return textosConLimite.allSatisfy { ($0.valor?.unicodeScalars.count ?? 0) <= $0.maximo }
    }

    /// Nombre a mostrar: el propio o el del programa.
    public func titulo(_ programa: Programa?) -> String { nombre ?? programa?.nombre ?? "" }
    public func unidadEfectiva(_ programa: Programa?) -> String { unidad ?? programa?.unidad ?? "puntos" }
    public func colorEfectivo(_ programa: Programa?) -> String { color ?? programa?.color ?? "#4F8248" }

    public static let saldoMaximo: Int64 = 1_000_000_000_000
}

/// Fechas «aaaa-mm-dd» en calendario gregoriano y zona local (como el tipo date de Postgres), aunque el
/// iPhone use otro calendario (japonés, budista…).
public enum Dia {
    public static var gregoriano: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    public static func texto(_ fecha: Date, calendario: Calendar = gregoriano) -> String {
        let c = calendario.dateComponents([.year, .month, .day], from: fecha)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func fecha(_ texto: String, calendario: Calendar = gregoriano) -> Date? {
        let partes = texto.split(separator: "-").compactMap { Int($0) }
        guard partes.count == 3 else { return nil }
        return calendario.date(from: DateComponents(year: partes[0], month: partes[1], day: partes[2]))
    }
}
