#if DEBUG
import Foundation
import RewardsCore

/// Datos de demostración para revisar el diseño y para capturas de la App Store, sin servidor.
/// Se lanza con `-demo YES` (solo en compilaciones Debug).
@MainActor
enum Demo {
    static var activo: Bool { UserDefaults.standard.bool(forKey: "demo") }
    static let yo = UUID(uuidString: "00000000-0000-4000-a000-0000000000d1")!
    static let ana = UUID(uuidString: "00000000-0000-4000-a000-0000000000d2")!
    static let familia = UUID(uuidString: "00000000-0000-4000-b000-0000000000d1")!

    static func programa(_ nombre: String, _ tipo: TipoPrograma, _ color: String, _ unidad: String, _ codigo: TipoCodigo) -> Programa {
        Programa(id: UUID(), nombre: nombre, tipo: tipo, pais: "MX", color: color, unidad: unidad, codigoTipo: codigo, activo: true)
    }

    static func datos() -> (programas: [Programa], mias: [Tarjeta], familia: [Tarjeta], miembros: [Miembro]) {
        let am = programa("Aeroméxico Rewards", .aerolinea, "#0B2343", "puntos", .ninguno)
        let bonvoy = programa("Marriott Bonvoy", .hotel, "#1C1C1C", "puntos", .ninguno)
        let soriana = programa("Soriana Recompensas", .comercio, "#D7182A", "puntos", .ean13)
        let starbucks = programa("Starbucks Rewards", .comercio, "#00704A", "estrellas", .qr)
        let amex = programa("American Express Membership Rewards", .tarjetaCredito, "#006FCF", "puntos", .ninguno)
        let liverpool = programa("Liverpool Monedero", .comercio, "#E10098", "pesos", .code128)
        let mias = [
            Tarjeta(userId: yo, programaId: am.id, numeroSocio: "00123456789", codigoValor: "00123456789", codigoTipo: .code128,
                    titular: "Manuel de la Torre", saldo: 48_200, saldoFecha: "2026-10-01", caducidad: "2027-06-30", compartida: true, orden: 0),
            Tarjeta(userId: yo, programaId: soriana.id, numeroSocio: "4006381333931", codigoValor: "4006381333931", codigoTipo: .ean13,
                    saldo: 1_250, compartida: true, orden: 1),
            Tarjeta(userId: yo, programaId: amex.id, numeroSocio: "3759 ••••", saldo: 92_400, orden: 2),
            Tarjeta(userId: yo, programaId: bonvoy.id, numeroSocio: "123 456 789", saldo: 31_500, caducidad: "2027-01-15", orden: 3),
        ]
        let deFamilia = [
            Tarjeta(userId: ana, programaId: starbucks.id, codigoValor: "SBX-7731-2290-4410", codigoTipo: .qr, saldo: 86, compartida: true),
            Tarjeta(userId: ana, programaId: liverpool.id, numeroSocio: "8899001122", codigoValor: "8899001122", codigoTipo: .code128,
                    saldo: 640, compartida: true, orden: 1),
        ]
        let miembros = [
            Miembro(userId: yo, familiaId: familia, nombre: "Manuel", rol: "admin", pais: "MX"),
            Miembro(userId: ana, familiaId: familia, nombre: "Ana", rol: "miembro", pais: "MX"),
        ]
        return ([am, bonvoy, soriana, starbucks, amex, liverpool], mias, deFamilia, miembros)
    }
}
#endif
