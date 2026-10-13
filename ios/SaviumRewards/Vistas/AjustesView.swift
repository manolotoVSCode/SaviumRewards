import SwiftUI
import RewardsCore

struct AjustesView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(Sesion.self) private var sesion
    @Environment(Bloqueo.self) private var bloqueo
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var confirmarSalida = false
    @State private var confirmarBorrado = false
    @State private var borrando = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tú") {
                    TextField("Tu nombre", text: $nombre)
                        .onSubmit(guardarNombre)
                    if let email = sesion.email { LabeledContent("Correo", value: email) }
                    Picker("Catálogo de", selection: Binding(get: { almacen.pais },
                                                             set: { p in Task { await almacen.cambiarPerfil(pais: p) } })) {
                        Text("México").tag("MX")
                        Text("España").tag("ES")
                    }
                }

                Section {
                    Toggle("Pedir Face ID al abrir", isOn: Binding(get: { bloqueo.activo }, set: { bloqueo.cambiarActivo($0) }))
                        .disabled(!bloqueo.disponible)
                    if bloqueo.activo && bloqueo.disponible {
                        Picker("Pedirlo al volver", selection: Binding(get: { bloqueo.plazo }, set: { bloqueo.cambiarPlazo($0) })) {
                            ForEach(PlazoBloqueo.allCases) { Text($0.titulo).tag($0) }
                        }
                    }
                } header: {
                    Text("Seguridad")
                } footer: {
                    if !bloqueo.disponible { Text("Activa Face ID o el código en los Ajustes del iPhone para usarlo.") }
                }

                Section {
                    ForEach(almacen.miembros) { m in
                        HStack {
                            Text(m.nombre)
                            Spacer()
                            if m.rol == "admin" { Text("Responsable").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                } header: {
                    Text(almacen.nombreFamilia ?? String(localized: "Familia"))
                } footer: {
                    Text(almacen.esAdmin
                         ? "Invita a tu familia desde Savium Finanzas (Apps → Savium Rewards)."
                         : "Quien administra la familia puede invitar a más personas.")
                }

                Section {
                    Link(destination: Config.privacidad) { Label("Política de privacidad", systemImage: "hand.raised") }
                    LabeledContent("Versión", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }

                Section {
                    Button("Cerrar sesión") { confirmarSalida = true }
                    Button("Eliminar mi cuenta", role: .destructive) { confirmarBorrado = true }
                        .disabled(borrando)
                } footer: {
                    Text("Eliminar la cuenta borra todas tus tarjetas, también las compartidas con tu familia.")
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", role: .confirm) { guardarNombre(); cerrar() }
                }
            }
            .onAppear { nombre = almacen.perfil?.nombre ?? "" }
            .confirmationDialog("¿Cerrar sesión en este iPhone?", isPresented: $confirmarSalida, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) {
                    almacen.cerrar(borrarDisco: true)
                    Task { await sesion.cerrar() }
                }
            } message: {
                Text(almacen.pendientes.isEmpty ? "" : String(localized: "Hay cambios sin sincronizar que se perderán."))
            }
            .confirmationDialog("¿Eliminar tu cuenta?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Eliminar cuenta y tarjetas", role: .destructive) {
                    Task {
                        borrando = true
                        if await almacen.eliminarCuenta() {
                            almacen.cerrar(borrarDisco: true)
                            await sesion.olvidar()
                        }
                        borrando = false
                    }
                }
            } message: {
                Text("No se puede deshacer.")
            }
        }
    }

    private func guardarNombre() {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        guard (1...40).contains(limpio.count), limpio != almacen.perfil?.nombre else { return }
        Task { await almacen.cambiarPerfil(nombre: limpio) }
    }
}
