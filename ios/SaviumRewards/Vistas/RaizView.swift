import SwiftUI

struct RaizView: View {
    @Environment(Sesion.self) private var sesion
    @Environment(Almacen.self) private var almacen
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
                    if almacen.pertenencia == .sinFamilia {
                        SinFamiliaView()
                    } else {
                        CarteraView()
                    }
                }
                .task(id: usuario) { await almacen.abrir(usuario: usuario) }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !bienvenidaVista && sesion.usuario != nil }, set: { _ in })) {
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
