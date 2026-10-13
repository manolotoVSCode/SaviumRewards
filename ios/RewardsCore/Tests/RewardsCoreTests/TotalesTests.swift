import Foundation
import Testing
@testable import RewardsCore

@Suite struct TotalesTests {
    let premier = Programa(id: UUID(), nombre: "Aeroméxico", tipo: .aerolinea, pais: "MX", color: "#0B2343",
                           unidad: "puntos", codigoTipo: .ninguno, activo: true)
    let iberia = Programa(id: UUID(), nombre: "Iberia", tipo: .aerolinea, pais: "ES", color: "#D7192D",
                          unidad: "Avios", codigoTipo: .ninguno, activo: true)

    @Test func sumaPorUnidadSinMezclar() {
        let t = [tarjeta("A", saldo: 1000, programa: premier.id), tarjeta("B", saldo: 500, programa: premier.id),
                 tarjeta("C", saldo: 300, programa: iberia.id)]
        let r = Totales.porUnidad(t, programas: [premier.id: premier, iberia.id: iberia])
        #expect(r == [TotalUnidad(unidad: "puntos", total: 1500), TotalUnidad(unidad: "Avios", total: 300)])
    }

    @Test func normalizaUnidad() {
        let t = [tarjeta("A", saldo: 10, unidad: "Puntos"), tarjeta("B", saldo: 5, unidad: " puntos ")]
        let r = Totales.porUnidad(t, programas: [:])
        #expect(r.count == 1)
        #expect(r.first?.total == 15)
    }

    @Test func ignoraSinSaldoYBorradas() {
        let t = [tarjeta("A"), tarjeta("B", saldo: 7, unidad: "pts", borrado: true), tarjeta("C", saldo: 3, unidad: "pts")]
        #expect(Totales.porUnidad(t, programas: [:]) == [TotalUnidad(unidad: "pts", total: 3)])
    }

    @Test func sinUnidadUsaPuntos() {
        #expect(Totales.porUnidad([tarjeta("A", saldo: 4)], programas: [:]) == [TotalUnidad(unidad: "puntos", total: 4)])
    }
}
