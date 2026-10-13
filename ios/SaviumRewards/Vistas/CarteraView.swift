import SwiftUI
import RewardsCore

/// Pantalla principal: mis tarjetas y las compartidas de la familia.
struct CarteraView: View {
    @Environment(Almacen.self) private var almacen
    @Namespace private var zoom
    @State private var busqueda = ""
    @State private var editando: Tarjeta?
    @State private var ordenando = false
    @State private var ajustes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    seccion("Mías", tarjetas: filtradas(almacen.visibles))
                    if !almacen.familia.isEmpty {
                        seccion("De la familia", tarjetas: filtradas(almacen.familia))
                    }
                    if almacen.visibles.isEmpty && almacen.familia.isEmpty { vacia }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Rewards")
            .searchable(text: $busqueda, prompt: "Buscar tarjeta")
            .refreshable { await almacen.sincronizar() }
            .navigationDestination(for: Tarjeta.self) { t in
                DetalleView(tarjetaId: t.id, inicial: t)
                    .navigationTransition(.zoom(sourceID: t.id, in: zoom))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ajustes", systemImage: "gearshape") { ajustes = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Añadir tarjeta", systemImage: "plus") { editando = almacen.nuevaTarjeta() }
                        .buttonStyle(.glassProminent)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Más", systemImage: "ellipsis") {
                        Button("Ordenar mis tarjetas", systemImage: "arrow.up.arrow.down") { ordenando = true }
                            .disabled(almacen.visibles.count < 2)
                    }
                }
            }
            .navigationSubtitle(estado)
            .sheet(item: $editando) { t in EditorView(tarjeta: t, nueva: true) }
            .sheet(isPresented: $ordenando) { OrdenarView() }
            .sheet(isPresented: $ajustes) { AjustesView() }
        }
    }

    @ViewBuilder
    private func seccion(_ titulo: LocalizedStringKey, tarjetas: [Tarjeta]) -> some View {
        if !tarjetas.isEmpty {
            Text(titulo).font(.title3.bold()).padding(.top, 8)
            ForEach(tarjetas) { t in
                NavigationLink(value: t) {
                    TarjetaVista(tarjeta: t, programa: almacen.programa(t),
                                 dueno: almacen.esMia(t) ? nil : almacen.dueno(t),
                                 pendiente: almacen.pendiente(t), rechazada: almacen.rechazada(t))
                        .matchedTransitionSource(id: t.id, in: zoom)
                }
                .buttonStyle(EstiloTarjeta())
                .contextMenu {
                    if almacen.esMia(t) {
                        Button("Editar", systemImage: "pencil") { editando = t }
                    }
                    if let socio = t.numeroSocio, !socio.isEmpty {
                        Button("Copiar número de socio", systemImage: "doc.on.doc") { UIPasteboard.general.string = socio }
                    }
                }
            }
        }
    }

    private var vacia: some View {
        ContentUnavailableView {
            Label("Tu cartera está vacía", systemImage: "wallet.pass")
        } description: {
            Text("Añade tus tarjetas de fidelidad para tenerlas siempre a mano, sin llevarlas encima.")
        }
        .padding(.top, 60)
    }

    private var estado: String {
        if almacen.sinConexion { return String(localized: "Sin conexión") }
        if !almacen.pendientes.isEmpty { return String(localized: "Pendiente de sincronizar") }
        return almacen.ultimoError ?? ""
    }

    private func filtradas(_ tarjetas: [Tarjeta]) -> [Tarjeta] {
        let q = busqueda.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return tarjetas }
        return tarjetas.filter { t in
            [t.titulo(almacen.programa(t)), t.numeroSocio ?? "", t.titular ?? "", almacen.dueno(t) ?? ""]
                .contains { $0.localizedStandardContains(q) }
        }
    }
}

/// Reordenar mis tarjetas arrastrando.
struct OrdenarView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var ids: [UUID] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(ids, id: \.self) { id in
                    if let t = almacen.visibles.first(where: { $0.id == id }) {
                        HStack {
                            Circle().fill(Color(hexTexto: t.colorEfectivo(almacen.programa(t)))).frame(width: 14, height: 14)
                            Text(t.titulo(almacen.programa(t)))
                        }
                    }
                }
                .onMove { ids.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Ordenar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", role: .confirm) { almacen.reordenar(ids); cerrar() }
                }
            }
            .onAppear { ids = almacen.visibles.map(\.id) }
        }
    }
}
