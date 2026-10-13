import SwiftUI

/// Pantalla de acceso con Face ID. Lo pide sola al aparecer (para enseñar una tarjeta en caja cuanto antes)
/// y deja el botón por si se cancela.
struct BloqueoView: View {
    @Environment(Bloqueo.self) private var bloqueo
    @State private var intentando = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("Logo")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)
            Text("Savium Rewards").font(.title.bold())
            Spacer()
            Button {
                Task { await intentar() }
            } label: {
                Label("Entrar con Face ID", systemImage: "faceid")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(intentando)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task { await intentar() }
    }

    private func intentar() async {
        guard !intentando else { return }
        intentando = true
        _ = await bloqueo.desbloquear()
        intentando = false
    }
}
