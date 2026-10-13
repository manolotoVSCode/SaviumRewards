import SwiftUI

/// Primera apertura: tres páginas que cuentan la app.
struct BienvenidaView: View {
    @AppStorage("bienvenidaVista") private var vista = false
    @State private var pagina = 0

    private struct Pagina: Identifiable {
        let id: Int
        let simbolo: String
        let colores: [Color]
        let titulo: LocalizedStringKey
        let texto: LocalizedStringKey
    }

    private let paginas = [
        Pagina(id: 0, simbolo: "wallet.pass.fill", colores: [Color(hex: 0x34A815), Color(hex: 0x239005)],
               titulo: "Todas tus tarjetas", texto: "Puntos, millas y monederos en un solo sitio, con su código listo para la caja."),
        Pagina(id: 1, simbolo: "barcode.viewfinder", colores: [Color(hex: 0x30C9C9), Color(hex: 0x0E7C86)],
               titulo: "Escanéalas", texto: "Apunta la cámara a la tarjeta y se guarda el código. También sin conexión."),
        Pagina(id: 2, simbolo: "person.2.fill", colores: [Color(hex: 0x7A6CFF), Color(hex: 0x3B2DBF)],
               titulo: "En familia", texto: "Comparte las que quieras: tu familia podrá enseñarlas en caja. Las demás son solo tuyas."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: paginas[pagina].colores, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom))
                .animation(.easeInOut(duration: 0.5), value: pagina)
                .ignoresSafeArea()
            TabView(selection: $pagina.animation(.snappy)) {
                ForEach(paginas) { p in
                    VStack(spacing: 28) {
                        Spacer()
                        Image(systemName: p.simbolo)
                            .font(.system(size: 70, weight: .semibold))
                            .frame(width: 150, height: 150)
                            .glassEffect(.regular, in: .rect(cornerRadius: 40, style: .continuous))
                        Text(p.titulo).font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text(p.texto).font(.title3).multilineTextAlignment(.center).opacity(0.9).padding(.horizontal, 32)
                        Spacer()
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .tag(p.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if pagina < paginas.count - 1 { withAnimation(.snappy) { pagina += 1 } } else { vista = true }
            } label: {
                Text(pagina < paginas.count - 1 ? "Continuar" : "Empezar").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .tint(.white.opacity(0.25))
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: pagina)
    }
}
