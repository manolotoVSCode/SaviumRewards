import SwiftUI

struct RaizView: View {
    @Environment(Sesion.self) private var sesion
    @Environment(Almacen.self) private var almacen
    @Environment(Bloqueo.self) private var bloqueo
    @Environment(\.scenePhase) private var fase
    @AppStorage("bienvenidaVista") private var bienvenidaVista = false

    var body: some View {
        Group {
            switch sesion.estado {
            case .cargando:
                ProgressView()
            case .fuera:
                EntrarView()
            case .dentro(let usuario):
                Group {
                    if bloqueo.bloqueado {
                        BloqueoView()
                    } else if almacen.pertenencia == .sinFamilia {
                        SinFamiliaView()
                    } else {
                        CarteraView()
                    }
                }
                .task(id: usuario) { await almacen.abrir(usuario: usuario) }
            }
        }
        .onChange(of: sesion.estado) { anterior, nuevo in
            // Acaba de entrar con su correo: no se le pide además Face ID.
            if anterior == .fuera, case .dentro = nuevo { bloqueo.recienAutenticado() }
        }
        .onChange(of: fase) { _, nueva in
            if nueva == .background { bloqueo.enSegundoPlano() }
            if nueva == .active { bloqueo.alVolver() }
        }
        .fullScreenCover(isPresented: Binding(get: { !bienvenidaVista && sesion.usuario != nil && !bloqueo.bloqueado }, set: { _ in })) {
            BienvenidaView()
        }
    }
}

/// Cuenta válida pero sin familia (p. ej. la quitaron): no hay nada que mostrar.
struct SinFamiliaView: View {
    @Environment(Sesion.self) private var sesion
    @Environment(Almacen.self) private var almacen

    var body: some View {
        ContentUnavailableView {
            Label("Sin familia", systemImage: "person.2.slash")
        } description: {
            Text("Tu cuenta no pertenece a ninguna familia de Savium Rewards. Pide a quien la administra que te invite.")
        } actions: {
            Button("Reintentar") { Task { await almacen.sincronizar() } }
            Button("Cerrar sesión") {
                almacen.cerrar(borrarDisco: true)
                Task { await sesion.cerrar() }
            }
        }
    }
}
