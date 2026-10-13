import SwiftUI
import RewardsCore

/// Tarjeta abierta para enseñarla en caja: código grande y brillo al máximo mientras está abierta.
struct DetalleView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    let tarjetaId: UUID
    let inicial: Tarjeta
    @State private var editando: Tarjeta?
    @State private var brilloPrevio: CGFloat?
    @State private var copiado = false

    private var tarjeta: Tarjeta {
        almacen.misTarjetas.first { $0.id == tarjetaId } ?? almacen.familia.first { $0.id == tarjetaId } ?? inicial
    }

    var body: some View {
        let t = tarjeta
        let programa = almacen.programa(t)
        ScrollView {
            VStack(spacing: 18) {
                TarjetaVista(tarjeta: t, programa: programa, dueno: almacen.esMia(t) ? nil : almacen.dueno(t),
                             rechazada: almacen.rechazada(t), grande: true)
                if almacen.rechazada(t) {
                    Label("El servidor no aceptó los datos de esta tarjeta. Edítala, revisa los campos y guarda de nuevo.",
                          systemImage: "exclamationmark.icloud")
                        .font(.footnote).foregroundStyle(.red)
                }

                if let valor = t.codigoValor, t.codigoTipo != .ninguno {
                    CodigoVista(valor: valor, tipo: t.codigoTipo)
                    Text(valor).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                }

                VStack(spacing: 0) {
                    if let socio = t.numeroSocio, !socio.isEmpty {
                        fila("Número de socio", socio, monoespaciado: true) {
                            Button(copiado ? "Copiado" : "Copiar", systemImage: copiado ? "checkmark" : "doc.on.doc") {
                                UIPasteboard.general.string = socio
                                copiado = true
                            }
                            .labelStyle(.iconOnly)
                            .sensoryFeedback(.success, trigger: copiado)
                        }
                    }
                    if let titular = t.titular, !titular.isEmpty { fila("Titular", titular) }
                    if let notas = t.notas, !notas.isEmpty { fila("Notas", notas) }
                    if !almacen.esMia(t), let dueno = almacen.dueno(t) { fila("De", dueno) }
                }
                .background(.background.secondary, in: .rect(cornerRadius: 20, style: .continuous))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(t.titulo(programa))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if almacen.esMia(t) {
                Button("Editar") { editando = t }
            }
        }
        .sheet(item: $editando) { EditorView(tarjeta: $0, nueva: false) }
        .onAppear { subirBrillo() }
        .onDisappear { restaurarBrillo() }
        .onChange(of: t.borrado) { _, borrado in if borrado { cerrar() } }
    }

    private func fila(_ titulo: LocalizedStringKey, _ valor: String, monoespaciado: Bool = false,
                      @ViewBuilder accion: () -> some View = { EmptyView() }) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.caption).foregroundStyle(.secondary)
                Text(valor).font(monoespaciado ? .system(.body, design: .monospaced) : .body).textSelection(.enabled)
            }
            Spacer()
            accion()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 16) }
    }

    private var pantalla: UIScreen? {
        (UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene)?.screen
    }

    private func subirBrillo() {
        guard let pantalla, tarjeta.codigoTipo != .ninguno, brilloPrevio == nil else { return }
        brilloPrevio = pantalla.brightness
        pantalla.brightness = 1
    }

    private func restaurarBrillo() {
        guard let pantalla, let brilloPrevio else { return }
        pantalla.brightness = brilloPrevio
        self.brilloPrevio = nil
    }
}
