import Foundation
import Testing
@testable import RewardsCore

struct CasosCodigos: Decodable {
    struct Validacion: Decodable { let tipo: String; let valor: String; let motivo: String? }
    struct Digito: Decodable { let digitos: String; let esperado: Int }
    struct Barra: Decodable { let tipo: String; let valor: String; let modulos: String }
    let validacion: [Validacion]
    let digitoControl: [Digito]
    let barras: [Barra]

    static func cargar() throws -> CasosCodigos {
        let url = try #require(Bundle.module.url(forResource: "codigos", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(CasosCodigos.self, from: Data(contentsOf: url))
    }
}

func tarjeta(_ nombre: String, saldo: Int64? = nil, unidad: String? = nil, programa: UUID? = nil,
             actualizado: TimeInterval = 0, borrado: Bool = false, id: UUID = UUID()) -> Tarjeta {
    Tarjeta(id: id, userId: UUID(uuidString: "00000000-0000-4000-a000-00000000000a")!, programaId: programa,
            nombre: nombre, unidad: unidad, codigoTipo: .ninguno, saldo: saldo,
            actualizado: Date(timeIntervalSince1970: actualizado), borrado: borrado)
}
