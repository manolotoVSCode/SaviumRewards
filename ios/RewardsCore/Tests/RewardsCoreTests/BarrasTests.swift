import Testing
@testable import RewardsCore

@Suite struct BarrasTests {
    private func cadena(_ m: [Bool]?) -> String? { m.map { $0.map { $0 ? "1" : "0" }.joined() } }

    @Test func ean13Estructura() throws {
        let m = try #require(cadena(Barras.modulos("4006381333931", tipo: .ean13)))
        #expect(m.count == 95)
        #expect(m.hasPrefix("101"))
        #expect(m.hasSuffix("101"))
        let centro = m.index(m.startIndex, offsetBy: 45)
        #expect(m[centro..<m.index(centro, offsetBy: 5)] == "01010")
    }

    @Test func upcAEsEAN13ConCero() throws {
        let upc = try #require(cadena(Barras.modulos("036000291452", tipo: .upca)))
        // Primer dígito 0 → todo L: 0 = 0001101, 3 = 0111101.
        #expect(upc.hasPrefix("101" + "0001101" + "0111101"))
        #expect(upc == cadena(Barras.modulos("0036000291452", tipo: .ean13)))
    }

    @Test func ean8Longitud() throws {
        let m = try #require(Barras.modulos("96385074", tipo: .ean8))
        #expect(m.count == 67)
    }

    @Test func code39Longitud() throws {
        let m = try #require(Barras.modulos("ABC", tipo: .code39))
        // (3 + 2 asteriscos) × 16 − 1 hueco final, con ancha = 3 estrechas.
        #expect(m.count == 5 * 16 - 1)
        #expect(m.first == true && m.last == true)
    }

    @Test func invalidosNoGeneran() {
        #expect(Barras.modulos("4006381333932", tipo: .ean13) == nil)
        #expect(Barras.modulos("abc", tipo: .code39) == nil)
        #expect(Barras.modulos("X", tipo: .qr) == nil)
    }

    @Test func coincideConJsBarcode() throws {
        // Referencia independiente generada con JsBarcode (web/scripts/fixtures_barras.mjs).
        // JsBarcode deja un espacio tras el último carácter de Code 39; los espacios finales son zona de silencio.
        func sinEspaciosFinales(_ s: String?) -> String? { s.map { String($0.reversed().drop { $0 == "0" }.reversed()) } }
        let casos = try CasosCodigos.cargar().barras
        #expect(!casos.isEmpty)
        for caso in casos {
            let tipo = try #require(TipoCodigo(rawValue: caso.tipo))
            #expect(sinEspaciosFinales(cadena(Barras.modulos(caso.valor, tipo: tipo))) == sinEspaciosFinales(caso.modulos),
                    "\(caso.tipo) «\(caso.valor)»")
        }
    }
}
