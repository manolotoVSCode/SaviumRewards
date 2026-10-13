import Foundation
import Testing
@testable import RewardsCore

@Suite struct ServidorTests {
    @Test func fechasDePostgres() throws {
        let base = try #require(Servidor.fecha("2026-10-13T19:55:25.000+00:00"))
        #expect(Servidor.fecha("2026-10-13T19:55:25.731234+00:00")?.timeIntervalSince(base) ?? 0 > 0.73)
        #expect(Servidor.fecha("2026-10-13T19:55:25+00:00") == base)
        #expect(Servidor.fecha("2026-10-13T19:55:25.5Z")?.timeIntervalSince(base) == 0.5)
        #expect(Servidor.fecha("2026-10-13T21:55:25.000+02:00") == base)
        #expect(Servidor.fecha("ayer") == nil)
    }

    @Test func idaYVueltaDeTarjeta() throws {
        let t = Tarjeta(userId: UUID(), programaId: UUID(), numeroSocio: "123", codigoValor: "4006381333931",
                        codigoTipo: .ean13, saldo: 1500, saldoFecha: "2026-10-01",
                        actualizado: Date(timeIntervalSince1970: 1_760_000_000.25))
        let datos = try Servidor.codificador.encode(t)
        let json = try #require(String(data: datos, encoding: .utf8))
        #expect(json.contains("\"codigo_tipo\":\"ean13\""))
        #expect(json.contains("\"user_id\""))
        let vuelta = try Servidor.decodificador.decode(Tarjeta.self, from: datos)
        #expect(vuelta == t)
    }
}

@Suite struct CodificacionTests {
    @Test func losVaciosViajanComoNull() throws {
        let t = Tarjeta(userId: UUID(), nombre: "X", saldo: nil, sincronizado: .now)
        let json = try #require(String(data: Servidor.codificador.encode(t), encoding: .utf8))
        #expect(json.contains("\"saldo\":null"))
        #expect(json.contains("\"programa_id\":null"))
        #expect(json.contains("\"codigo_valor\":null"))
        #expect(!json.contains("sincronizado"))
    }

    @Test func limitesDelServidor() {
        var t = Tarjeta(userId: UUID(), nombre: "Tienda")
        #expect(t.cumpleLimites)
        t.numeroSocio = String(repeating: "1", count: 65)
        #expect(!t.cumpleLimites)
        t.numeroSocio = nil
        t.nombre = nil
        #expect(!t.cumpleLimites)
        t.nombre = "Tienda"; t.codigoTipo = .qr
        #expect(!t.cumpleLimites)
        t.codigoValor = "abc"
        #expect(t.cumpleLimites)
    }

    @Test func diasEnGregorianoAunqueElCalendarioSeaOtro() throws {
        var japones = Calendar(identifier: .japanese)
        japones.timeZone = .current
        let fecha = try #require(Dia.gregoriano.date(from: DateComponents(year: 2026, month: 10, day: 13)))
        #expect(Dia.texto(fecha) == "2026-10-13")
        #expect(Dia.texto(fecha, calendario: japones) != "2026-10-13")
    }
}
