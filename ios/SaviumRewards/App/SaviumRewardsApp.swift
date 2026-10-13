import SwiftUI

@main
struct SaviumRewardsApp: App {
    @State private var sesion = Sesion()
    @State private var almacen = Almacen()
    @State private var bloqueo = Bloqueo()
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(sesion)
                .environment(almacen)
                .environment(bloqueo)
                .onChange(of: fase) { _, nueva in
                    if nueva == .active { Task { await almacen.sincronizar() } }
                }
                .onChange(of: sesion.estado) { _, estado in
                    if estado == .fuera { almacen.cerrar(borrarDisco: false) }
                }
        }
    }
}
