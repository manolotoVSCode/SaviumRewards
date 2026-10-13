import SwiftUI

/// Entrada con correo y código de 6 dígitos. Solo para correos invitados.
struct EntrarView: View {
    @Environment(Sesion.self) private var sesion
    @State private var email = ""
    @State private var codigo = ""
    @State private var codigoEnviado = false
    @State private var enviando = false
    @FocusState private var campo: Campo?
    private enum Campo { case email, codigo }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(LinearGradient(colors: [Color(hex: 0x34A815), Color(hex: 0x239005)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: .rect(cornerRadius: 30, style: .continuous))
                    .padding(.top, 50)
                VStack(spacing: 6) {
                    Text("Savium Rewards").font(.largeTitle.bold())
                    FraseSavium().font(.callout).foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Correo electrónico", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($campo, equals: .email)
                        .disabled(codigoEnviado)
                        .padding(14)
                        .background(.background.secondary, in: .rect(cornerRadius: 14, style: .continuous))

                    if codigoEnviado {
                        TextField("Código de 6 dígitos", text: $codigo)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .font(.system(.title3, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .focused($campo, equals: .codigo)
                            .padding(14)
                            .background(.background.secondary, in: .rect(cornerRadius: 14, style: .continuous))
                            .onChange(of: codigo) { _, nuevo in
                                if nuevo.filter(\.isNumber).count >= 6 { Task { await verificar() } }
                            }
                        Text("Te hemos enviado un código a \(email).").font(.footnote).foregroundStyle(.secondary)
                    }

                    if let mensaje = sesion.mensaje {
                        Text(mensaje).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    Button {
                        Task { codigoEnviado ? await verificar() : await enviar() }
                    } label: {
                        Group {
                            if enviando { ProgressView() } else { Text(codigoEnviado ? "Entrar" : "Enviarme un código") }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(enviando || (codigoEnviado ? codigo.filter(\.isNumber).count < 6 : !email.contains("@")))

                    if codigoEnviado {
                        Button("Usar otro correo") {
                            codigoEnviado = false
                            codigo = ""
                            sesion.mensaje = nil
                            campo = .email
                        }
                        .font(.footnote)
                    }
                }
                .padding(.horizontal, 24)

                Text("Savium Rewards es solo por invitación: reúne las tarjetas de puntos y monederos de tu familia.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { campo = .email }
    }

    private func enviar() async {
        enviando = true
        defer { enviando = false }
        if await sesion.pedirCodigo(email: email) {
            codigoEnviado = true
            campo = .codigo
        }
    }

    private func verificar() async {
        guard !enviando else { return }
        enviando = true
        defer { enviando = false }
        if !(await sesion.verificar(email: email, codigo: codigo)) { codigo = "" }
    }
}
