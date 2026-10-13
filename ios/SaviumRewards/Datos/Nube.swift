import Foundation
import Supabase
import RewardsCore

// emitLocalSessionAsInitialSession: sin red y con el token caducado se entra con la sesión guardada
// (la cartera tiene que abrirse en caja aunque no haya cobertura).
let supabase = SupabaseClient(
    supabaseURL: Config.supabaseURL,
    supabaseKey: Config.supabaseClave,
    options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
)

struct Miembro: Codable, Identifiable, Hashable, Sendable {
    var userId: UUID
    var familiaId: UUID
    var nombre: String
    var rol: String
    var pais: String
    var id: UUID { userId }
}

struct Familia: Codable, Hashable, Sendable {
    var id: UUID
    var nombre: String
}

/// Única puerta a Supabase. Las reglas de acceso limitan todo al usuario de la sesión y a su familia.
struct Nube: Sendable {
    let db: SupabaseClient

    private func filas<T: Decodable>(_ consulta: PostgrestBuilder) async throws -> [T] {
        try Servidor.decodificador.decode([T].self, from: await consulta.execute().data)
    }

    /// Codifica con snake_case y fechas ISO 8601, y lo pasa a AnyJSON para que PostgREST lo reciba tal cual.
    private func json<T: Encodable>(_ valor: T) throws -> AnyJSON {
        try JSONDecoder().decode(AnyJSON.self, from: Servidor.codificador.encode(valor))
    }

    func perfil(_ usuario: UUID) async throws -> (Miembro, Familia?, admin: Bool)? {
        let miembros: [Miembro] = try await filas(db.from("rewards_miembros").select("user_id, familia_id, nombre, rol, pais")
            .eq("user_id", value: usuario))
        guard let yo = miembros.first else { return nil }
        let familias: [Familia] = try await filas(db.from("rewards_familias").select("id, nombre").eq("id", value: yo.familiaId))
        struct Fila: Decodable { let userId: UUID }
        let admins: [Fila] = try await filas(db.from("rewards_admins").select("user_id").eq("user_id", value: usuario))
        return (yo, familias.first, !admins.isEmpty)
    }

    func miembros(familia: UUID) async throws -> [Miembro] {
        try await filas(db.from("rewards_miembros").select("user_id, familia_id, nombre, rol, pais")
            .eq("familia_id", value: familia).order("nombre"))
    }

    func programas() async throws -> [Programa] {
        try await filas(db.from("rewards_programas").select("id, nombre, tipo, pais, color, unidad, codigo_tipo, activo").order("nombre"))
    }

    /// Mis tarjetas cambiadas desde el cursor (con margen, por si una transacción tardó en confirmarse).
    func misTarjetas(_ usuario: UUID, desde cursor: Date?) async throws -> [Tarjeta] {
        var consulta = db.from("rewards_tarjetas").select().eq("user_id", value: usuario)
        if let cursor { consulta = consulta.gt("sincronizado", value: Servidor.texto(cursor.addingTimeInterval(-10))) }
        return try await filas(consulta)
    }

    /// Todas las compartidas de la familia (las reglas de acceso ya filtran las privadas y las borradas).
    func tarjetasFamilia(_ usuario: UUID) async throws -> [Tarjeta] {
        try await filas(db.from("rewards_tarjetas").select().neq("user_id", value: usuario))
    }

    func subir(_ tarjetas: [Tarjeta]) async throws {
        guard !tarjetas.isEmpty else { return }
        try await db.from("rewards_tarjetas").upsert(json(tarjetas), onConflict: "id", returning: .minimal).execute()
    }

    func actualizarPerfil(_ usuario: UUID, nombre: String? = nil, pais: String? = nil, sincronizado: Date? = nil) async throws {
        var cambios: [String: AnyJSON] = [:]
        if let nombre { cambios["nombre"] = .string(nombre) }
        if let pais { cambios["pais"] = .string(pais) }
        if let sincronizado { cambios["ultima_sincronizacion"] = .string(Servidor.texto(sincronizado)) }
        guard !cambios.isEmpty else { return }
        try await db.from("rewards_miembros").update(cambios, returning: .minimal).eq("user_id", value: usuario).execute()
    }

    func eliminarCuenta() async throws {
        struct Cuerpo: Encodable { let accion = "eliminar" }
        try await db.functions.invoke("rewards-cuenta", options: FunctionInvokeOptions(body: Cuerpo()))
    }
}
