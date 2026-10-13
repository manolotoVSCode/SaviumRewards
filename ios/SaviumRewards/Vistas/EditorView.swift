import SwiftUI
import RewardsCore

/// Alta y edición de una tarjeta: programa del catálogo u «Otro» y su código (escaneado o escrito).
struct EditorView: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var t: Tarjeta
    private let original: Tarjeta
    let nueva: Bool

    @State private var valor: String
    @State private var escaneando = false
    @State private var confirmarBorrado = false
    @State private var otroPrograma: Bool

    init(tarjeta: Tarjeta, nueva: Bool) {
        _t = State(initialValue: tarjeta)
        original = tarjeta
        self.nueva = nueva
        _valor = State(initialValue: tarjeta.codigoValor ?? "")
        _otroPrograma = State(initialValue: !nueva && tarjeta.programaId == nil)
    }

    private var programa: Programa? { t.programaId.flatMap { almacen.programas[$0] } }
    private var validacion: Codigos.Resultado { Codigos.validar(valor, tipo: t.codigoTipo) }
    private var nombreValido: Bool { t.programaId != nil || !(t.nombre ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    private var textosValidos: Bool { t.textosConLimite.allSatisfy { ($0.valor?.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count ?? 0) <= $0.maximo } }
    private var puedeGuardar: Bool { validacion == .valido && nombreValido && textosValidos }

    var body: some View {
        NavigationStack {
            Form {
                seccionPrograma
                seccionCodigo
                Section {
                    TextField("Titular", text: opcional(\.titular))
                    TextField("Notas", text: opcional(\.notas), axis: .vertical).lineLimit(2...6)
                }
                Section {
                    Toggle("Compartir con la familia", isOn: $t.compartida)
                } footer: {
                    Text("Tu familia podrá verla y enseñar su código. Solo tú puedes cambiarla.")
                }
                if !textosValidos {
                    Section { Text("Algún texto es demasiado largo (nombre 60, número de socio 64, titular 60, notas 1000).").foregroundStyle(.red) }
                }
                if !nueva {
                    Section {
                        Button("Borrar tarjeta", role: .destructive) { confirmarBorrado = true }
                    }
                }
            }
            .navigationTitle(nueva ? "Nueva tarjeta" : "Editar tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", role: .confirm, action: guardar).disabled(!puedeGuardar)
                }
            }
            .sheet(isPresented: $escaneando) {
                EscanerView { leido, tipo in
                    t.codigoTipo = tipo
                    valor = leido
                    if (t.numeroSocio ?? "").isEmpty, tipo.esLineal, leido.unicodeScalars.count <= 64 { t.numeroSocio = leido }
                }
            }
            .confirmationDialog("¿Borrar esta tarjeta?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    // Se borra la versión guardada, no lo que se estaba editando.
                    almacen.borrar(original)
                    cerrar()
                }
            } message: {
                Text("También desaparecerá de la cartera de tu familia.")
            }
        }
    }

    // MARK: Secciones

    @ViewBuilder
    private var seccionPrograma: some View {
        Section {
            NavigationLink {
                CatalogoView { elegido in
                    if let elegido {
                        t.programaId = elegido.id
                        t.nombre = nil
                        t.color = nil
                        t.unidad = nil
                        if valor.isEmpty { t.codigoTipo = elegido.codigoTipo }
                        otroPrograma = false
                    } else {
                        t.programaId = nil
                        t.color = t.color ?? Paleta.propios.randomElement()
                        otroPrograma = true
                    }
                }
            } label: {
                HStack {
                    Circle().fill(Color(hexTexto: t.colorEfectivo(programa))).frame(width: 14, height: 14)
                    Text(programa?.nombre ?? (otroPrograma ? String(localized: "Otro programa") : String(localized: "Elegir programa")))
                        .foregroundStyle(programa == nil && !otroPrograma ? .secondary : .primary)
                }
            }
            if otroPrograma {
                TextField("Nombre de la tarjeta", text: opcional(\.nombre))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Paleta.propios, id: \.self) { hex in
                            Button {
                                t.color = hex
                            } label: {
                                Circle().fill(Color(hexTexto: hex)).frame(width: 30, height: 30)
                                    .overlay { if t.color == hex { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                        }
                    }
                }
            }
        } header: {
            Text("Programa")
        } footer: {
            if !nombreValido { Text("Elige un programa o escribe el nombre de la tarjeta.") }
        }
    }

    @ViewBuilder
    private var seccionCodigo: some View {
        Section {
            Button("Escanear con la cámara", systemImage: "barcode.viewfinder") { escaneando = true }
            Picker("Tipo de código", selection: $t.codigoTipo) {
                ForEach(TipoCodigo.allCases, id: \.self) { Text($0.nombre).tag($0) }
            }
            if t.codigoTipo != .ninguno {
                TextField("Contenido del código", text: $valor, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(t.codigoTipo == .code39 ? .characters : .never)
                    .autocorrectionDisabled()
                    .keyboardType([.ean13, .ean8, .upca].contains(t.codigoTipo) ? .numberPad : .asciiCapable)
                if case .invalido(let motivo) = validacion, !valor.isEmpty {
                    Text(motivo.texto).font(.footnote).foregroundStyle(.red)
                    if let completo = Codigos.completar(valor, tipo: t.codigoTipo) {
                        Button("Usar \(completo)") { valor = completo }
                    }
                }
                if validacion == .valido {
                    CodigoVista(valor: valor, tipo: t.codigoTipo).listRowInsets(EdgeInsets())
                }
            }
            TextField("Número de socio", text: opcional(\.numeroSocio))
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
        } header: {
            Text("Código")
        } footer: {
            Text("Si la tarjeta no tiene código, elige «Sin código» y guarda solo el número de socio.")
        }
        .onChange(of: t.codigoTipo) { _, tipo in if tipo == .ninguno { valor = "" } }
    }

    // MARK: Guardar

    private func guardar() {
        var final = t
        final.codigoValor = t.codigoTipo == .ninguno ? nil : Codigos.normalizar(valor, tipo: t.codigoTipo)
        for campo in [\Tarjeta.nombre, \.unidad, \.numeroSocio, \.titular, \.notas] {
            let limpio = final[keyPath: campo]?.trimmingCharacters(in: .whitespacesAndNewlines)
            final[keyPath: campo] = (limpio?.isEmpty ?? true) ? nil : limpio
        }
        if final.programaId != nil { final.nombre = nil }
        almacen.guardar(final)
        cerrar()
    }

    private func opcional(_ campo: WritableKeyPath<Tarjeta, String?>) -> Binding<String> {
        Binding(get: { t[keyPath: campo] ?? "" }, set: { t[keyPath: campo] = $0 })
    }
}
