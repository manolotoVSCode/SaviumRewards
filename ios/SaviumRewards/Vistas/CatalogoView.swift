import SwiftUI
import RewardsCore

/// Elegir programa del catálogo (primero los del país del usuario y los internacionales) u «Otro programa».
struct CatalogoView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    let elegir: (Programa?) -> Void
    @State private var busqueda = ""
    @State private var todos = false

    var body: some View {
        List {
            Section {
                Button {
                    elegir(nil)
                    cerrar()
                } label: {
                    Label("Otro programa", systemImage: "plus.circle")
                }
            }
            ForEach(TipoPrograma.allCases, id: \.self) { tipo in
                let lista = filtrados.filter { $0.tipo == tipo }
                if !lista.isEmpty {
                    Section {
                        ForEach(lista) { p in
                            Button {
                                elegir(p)
                                cerrar()
                            } label: {
                                HStack {
                                    Circle().fill(Color(hexTexto: p.color)).frame(width: 14, height: 14)
                                    Text(p.nombre).foregroundStyle(.primary)
                                    Spacer()
                                    if todos { Text(p.pais).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    } header: {
                        Label { Text(tipo.nombre) } icon: { Image(systemName: tipo.simbolo) }
                    }
                }
            }
        }
        .navigationTitle("Programa")
        .searchable(text: $busqueda, prompt: "Buscar programa")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mostrar", selection: $todos) {
                    Text(almacen.pais == "ES" ? "España" : "México").tag(false)
                    Text("Todos").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .overlay {
            if almacen.programas.isEmpty {
                ContentUnavailableView("Catálogo sin cargar", systemImage: "icloud.slash",
                                       description: Text("Conéctate para descargar el catálogo, o usa «Otro programa»."))
            }
        }
    }

    private var filtrados: [Programa] {
        almacen.programasOrdenados.filter { p in
            (todos || p.pais == almacen.pais || p.pais == "INT")
                && (busqueda.isEmpty || p.nombre.localizedStandardContains(busqueda))
        }
    }
}
