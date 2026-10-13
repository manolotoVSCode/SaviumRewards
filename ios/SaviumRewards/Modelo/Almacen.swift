import Foundation
import Network
import Observation
import RewardsCore
import Supabase

/// Estado de la cartera: se guarda en el iPhone (para abrirla sin cobertura) y se sincroniza con Supabase.
@Observable @MainActor
final class Almacen {
    private struct Guardado: Codable {
        var misTarjetas: [Tarjeta] = []
        var familia: [Tarjeta] = []
        var programas: [Programa] = []
        var miembros: [Miembro] = []
        var perfil: Miembro?
        var nombreFamilia: String?
        var esAdmin = false
        var pendientes: Set<UUID> = []
        var rechazadas: Set<UUID>? = []
        var cursor: Date?
    }

    enum Pertenencia: Equatable { case desconocida, miembro, sinFamilia }

    private(set) var misTarjetas: [Tarjeta] = []
    private(set) var familia: [Tarjeta] = []
    private(set) var programas: [UUID: Programa] = [:]
    private(set) var miembros: [Miembro] = []
    private(set) var perfil: Miembro?
    private(set) var nombreFamilia: String?
    private(set) var esAdmin = false
    private(set) var pendientes: Set<UUID> = []
    private(set) var pertenencia: Pertenencia = .desconocida
    private(set) var sincronizando = false
    private(set) var sinConexion = false
    private(set) var ultimoError: String?
    /// Tarjetas que el servidor rechazó (no bloquean al resto); se reintentan al editarlas.
    private(set) var rechazadas: Set<UUID> = []

    private var cursor: Date?
    private var usuario: UUID?
    private var otraVez = false
    private let nube = Nube(db: supabase)
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] ruta in
            let conectado = ruta.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let volvio = self.sinConexion && conectado
                self.sinConexion = !conectado
                if volvio { await self.sincronizar() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "rewards.red"))
    }

    // MARK: Consultas

    var visibles: [Tarjeta] { misTarjetas.filter { !$0.borrado } }
    var programasOrdenados: [Programa] { programas.values.filter(\.activo).sorted { $0.nombre.localizedStandardCompare($1.nombre) == .orderedAscending } }
    func programa(_ t: Tarjeta) -> Programa? { t.programaId.flatMap { programas[$0] } }
    func dueno(_ t: Tarjeta) -> String? { miembros.first { $0.userId == t.userId }?.nombre }
    func esMia(_ t: Tarjeta) -> Bool { t.userId == usuario }
    func pendiente(_ t: Tarjeta) -> Bool { pendientes.contains(t.id) }
    func rechazada(_ t: Tarjeta) -> Bool { rechazadas.contains(t.id) }
    var pais: String { perfil?.pais ?? (Locale.current.region?.identifier == "ES" ? "ES" : "MX") }

    // MARK: Ciclo de vida

    func abrir(usuario: UUID) async {
        guard self.usuario != usuario else { return }
        self.usuario = usuario
        #if DEBUG
        if Demo.activo { cargarDemo(); return }
        #endif
        cargarDeDisco()
        await sincronizar()
    }

    /// Vacía la memoria. El archivo local solo se borra al cerrar sesión a propósito o eliminar la cuenta:
    /// si la sesión caduca, se conserva (con sus cambios pendientes) para cuando vuelva a entrar.
    func cerrar(borrarDisco: Bool) {
        if borrarDisco, let usuario { try? FileManager.default.removeItem(at: archivo(usuario)) }
        usuario = nil
        misTarjetas = []; familia = []; programas = [:]; miembros = []; perfil = nil; nombreFamilia = nil
        esAdmin = false; pendientes = []; cursor = nil; pertenencia = .desconocida; ultimoError = nil; rechazadas = []
    }

    // MARK: Cambios locales

    func nuevaTarjeta() -> Tarjeta {
        Tarjeta(userId: usuario ?? UUID(), orden: (visibles.map(\.orden).max() ?? -1) + 1)
    }

    func guardar(_ tarjeta: Tarjeta) {
        var t = tarjeta
        t.actualizado = .now
        if let i = misTarjetas.firstIndex(where: { $0.id == t.id }) { misTarjetas[i] = t } else { misTarjetas.append(t) }
        misTarjetas = Fusion.ordenadas(misTarjetas)
        pendientes.insert(t.id)
        rechazadas.remove(t.id)
        guardarEnDisco()
        Task { await sincronizar() }
    }

    func borrar(_ tarjeta: Tarjeta) {
        var t = tarjeta
        t.borrado = true
        guardar(t)
    }

    func reordenar(_ ids: [UUID]) {
        for (orden, id) in ids.enumerated() {
            guard let i = misTarjetas.firstIndex(where: { $0.id == id }), misTarjetas[i].orden != orden else { continue }
            misTarjetas[i].orden = orden
            misTarjetas[i].actualizado = .now
            pendientes.insert(id)
        }
        misTarjetas = Fusion.ordenadas(misTarjetas)
        guardarEnDisco()
        Task { await sincronizar() }
    }

    func cambiarPerfil(nombre: String? = nil, pais: String? = nil) async {
        guard let usuario else { return }
        do {
            try await nube.actualizarPerfil(usuario, nombre: nombre, pais: pais)
            if let nombre { perfil?.nombre = nombre }
            if let pais { perfil?.pais = pais }
            guardarEnDisco()
        } catch {
            ultimoError = String(localized: "No se pudo guardar el cambio. Revisa la conexión.")
        }
    }

    func eliminarCuenta() async -> Bool {
        do {
            try await nube.eliminarCuenta()
            return true
        } catch {
            ultimoError = String(localized: "No se pudo eliminar la cuenta. Inténtalo de nuevo con conexión.")
            return false
        }
    }

    // MARK: Sincronización

    func sincronizar() async {
        guard let usuario else { return }
        #if DEBUG
        if Demo.activo { pendientes = []; return }
        #endif
        if sincronizando { otraVez = true; return }
        sincronizando = true
        defer {
            sincronizando = false
            if otraVez { otraVez = false; Task { await sincronizar() } }
        }
        do {
            guard let (yo, familiaInfo, admin) = try await nube.perfil(usuario) else {
                // Le han quitado de la familia: fuera también la copia local de las tarjetas compartidas.
                pertenencia = .sinFamilia
                familia = []; miembros = []; perfil = nil; nombreFamilia = nil; esAdmin = false
                guardarEnDisco()
                return
            }
            guard self.usuario == usuario else { return }
            pertenencia = .miembro
            perfil = yo; nombreFamilia = familiaInfo?.nombre; esAdmin = admin

            // Subir: se toma una foto de lo pendiente; si se edita mientras sube, sigue pendiente.
            // Una tarjeta inválida no bloquea al resto ni la descarga: queda marcada y pendiente.
            let candidatas = misTarjetas.filter { pendientes.contains($0.id) && !rechazadas.contains($0.id) }
            let aSubir = candidatas.filter(\.cumpleLimites)
            rechazadas.formUnion(candidatas.filter { !$0.cumpleLimites }.map(\.id))
            var subidas: [Tarjeta] = []
            do {
                try await nube.subir(aSubir)
                subidas = aSubir
            } catch {
                for t in aSubir {
                    do { try await nube.subir([t]); subidas.append(t) } catch let error as PostgrestError {
                        // Rechazo del servidor (CHECK, RLS): se marca. Un fallo de red se reintenta luego.
                        if error.code?.hasPrefix("23") == true || error.code == "42501" { rechazadas.insert(t.id) } else { throw error }
                    }
                }
            }
            for t in subidas where misTarjetas.first(where: { $0.id == t.id })?.actualizado == t.actualizado {
                pendientes.remove(t.id)
            }

            async let propias = nube.misTarjetas(usuario, desde: cursor)
            async let deFamilia = nube.tarjetasFamilia(usuario)
            async let catalogo = nube.programas()
            async let gente = nube.miembros(familia: yo.familiaId)
            let (servidor, compartidas, listaProgramas, listaMiembros) = try await (propias, deFamilia, catalogo, gente)
            guard self.usuario == usuario else { return }

            let fusion = Fusion.aplicar(locales: misTarjetas, pendientes: pendientes, servidor: servidor)
            misTarjetas = fusion.tarjetas
            pendientes = fusion.pendientes
            cursor = servidor.compactMap(\.sincronizado).max().map { max($0, cursor ?? $0) } ?? cursor
            familia = Fusion.familia(servidor: compartidas)
            programas = Dictionary(listaProgramas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            miembros = listaMiembros
            ultimoError = rechazadas.isEmpty ? nil : String(localized: "Alguna tarjeta no se pudo guardar en el servidor. Ábrela y revisa sus datos.")
            guardarEnDisco()
            try? await nube.actualizarPerfil(usuario, sincronizado: .now)
        } catch is CancellationError {
        } catch {
            ultimoError = sinConexion ? nil : String(localized: "No se pudo sincronizar. Se reintentará solo.")
        }
    }

    #if DEBUG
    private func cargarDemo() {
        let d = Demo.datos()
        programas = Dictionary(uniqueKeysWithValues: d.programas.map { ($0.id, $0) })
        misTarjetas = d.mias; familia = d.familia; miembros = d.miembros
        perfil = d.miembros.first; nombreFamilia = "Familia de la Torre"; esAdmin = true; pertenencia = .miembro
    }
    #endif

    // MARK: Disco

    private func archivo(_ usuario: UUID) -> URL {
        let carpeta = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta.appending(path: "rewards-\(usuario.uuidString.lowercased()).json")
    }

    private func cargarDeDisco() {
        guard let usuario, let datos = try? Data(contentsOf: archivo(usuario)),
              let g = try? JSONDecoder().decode(Guardado.self, from: datos) else { return }
        misTarjetas = g.misTarjetas; familia = g.familia; miembros = g.miembros; perfil = g.perfil
        programas = Dictionary(g.programas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        nombreFamilia = g.nombreFamilia; esAdmin = g.esAdmin; pendientes = g.pendientes; cursor = g.cursor
        rechazadas = g.rechazadas ?? []
        if g.perfil != nil { pertenencia = .miembro }
    }

    private func guardarEnDisco() {
        guard let usuario else { return }
        let g = Guardado(misTarjetas: misTarjetas, familia: familia, programas: Array(programas.values), miembros: miembros,
                         perfil: perfil, nombreFamilia: nombreFamilia, esAdmin: esAdmin, pendientes: pendientes,
                         rechazadas: rechazadas, cursor: cursor)
        guard let datos = try? JSONEncoder().encode(g) else { return }
        try? datos.write(to: archivo(usuario), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
