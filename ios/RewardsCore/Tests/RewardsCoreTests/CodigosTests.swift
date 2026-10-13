import Testing
@testable import RewardsCore

@Suite struct CodigosTests {
    @Test func casosCompartidos() throws {
        for caso in try CasosCodigos.cargar().validacion {
            let tipo = try #require(TipoCodigo(rawValue: caso.tipo))
            let resultado = Codigos.validar(caso.valor, tipo: tipo)
            #expect(resultado.motivo?.rawValue == caso.motivo, "\(caso.tipo) «\(caso.valor)»")
        }
    }

    @Test func digitoDeControl() throws {
        for caso in try CasosCodigos.cargar().digitoControl {
            #expect(Codigos.digitoControl(caso.digitos) == caso.esperado, "\(caso.digitos)")
        }
        #expect(Codigos.digitoControl("12a") == nil)
    }

    @Test func completarEAN13Con12Digitos() {
        #expect(Codigos.completar("400638133393", tipo: .ean13) == "4006381333931")
        #expect(Codigos.completar("4006381333931", tipo: .ean13) == nil)
        #expect(Codigos.completar("96385 07", tipo: .ean8) == "96385074")
    }

    @Test func normalizaEspacios() {
        #expect(Codigos.normalizar(" 4006 3813 3393 1 ", tipo: .ean13) == "4006381333931")
        #expect(Codigos.normalizar("  Socio 1  ", tipo: .code128) == "Socio 1")
        #expect(Codigos.normalizar("  ", tipo: .ninguno) == "")
    }
}
