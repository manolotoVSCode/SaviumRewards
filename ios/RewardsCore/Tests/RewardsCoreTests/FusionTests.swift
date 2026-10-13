import Foundation
import Testing
@testable import RewardsCore

@Suite struct FusionTests {
    let id = UUID()

    @Test func ganaLaMasReciente() {
        let local = tarjeta("Local", actualizado: 200, id: id)
        let servidor = tarjeta("Servidor", actualizado: 100, id: id)
        let r = Fusion.aplicar(locales: [local], pendientes: [id], servidor: [servidor])
        #expect(r.tarjetas.map(\.nombre) == ["Local"])
        #expect(r.pendientes == [id])
    }

    @Test func servidorMasRecienteSustituyeYLiberaPendiente() {
        let local = tarjeta("Local", actualizado: 100, id: id)
        let servidor = tarjeta("Servidor", actualizado: 200, id: id)
        let r = Fusion.aplicar(locales: [local], pendientes: [id], servidor: [servidor])
        #expect(r.tarjetas.map(\.nombre) == ["Servidor"])
        #expect(r.pendientes.isEmpty)
    }

    @Test func pendienteNoSePisaConLaMisma() {
        // El servidor devuelve justo lo que subimos (misma marca): ya no está pendiente.
        let local = tarjeta("Igual", actualizado: 150, id: id)
        let r = Fusion.aplicar(locales: [local], pendientes: [id], servidor: [local])
        #expect(r.tarjetas.count == 1)
        #expect(r.pendientes.isEmpty)
    }

    @Test func sinPendienteTomaServidor() {
        let local = tarjeta("Local", actualizado: 300, id: id)
        let servidor = tarjeta("Servidor", actualizado: 100, id: id)
        let r = Fusion.aplicar(locales: [local], pendientes: [], servidor: [servidor])
        #expect(r.tarjetas.map(\.nombre) == ["Servidor"])
    }

    @Test func anadeNuevasDelServidor() {
        let r = Fusion.aplicar(locales: [tarjeta("A")], pendientes: [], servidor: [tarjeta("B")])
        #expect(Set(r.tarjetas.compactMap(\.nombre)) == ["A", "B"])
    }

    @Test func retiraFamiliaQueYaNoLlega() {
        // La lista de la familia se reemplaza entera: lo que ya no llega (se hizo privado) desaparece.
        let r = Fusion.familia(servidor: [tarjeta("Sigue"), tarjeta("Borrada", borrado: true)])
        #expect(r.map(\.nombre) == ["Sigue"])
    }

    @Test func ordenEstable() {
        var a = tarjeta("A"); a.orden = 2
        var b = tarjeta("B"); b.orden = 1
        #expect(Fusion.ordenadas([a, b]).map(\.nombre) == ["B", "A"])
    }
}
