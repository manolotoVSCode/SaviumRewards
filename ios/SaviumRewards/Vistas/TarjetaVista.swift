import SwiftUI
import RewardsCore

/// Tarjeta estilo Wallet: color del programa, nombre, número de socio y, si es de otro miembro, de quién es.
struct TarjetaVista: View {
    let tarjeta: Tarjeta
    let programa: Programa?
    var dueno: String? = nil
    var pendiente = false
    var rechazada = false
    var grande = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(iniciales)
                    .font(.system(size: grande ? 22 : 18, weight: .bold, design: .rounded))
                    .frame(width: grande ? 54 : 46, height: grande ? 54 : 46)
                    .background(.white.opacity(0.22), in: .rect(cornerRadius: grande ? 16 : 14, style: .continuous))
                Spacer()
                HStack(spacing: 6) {
                    if rechazada {
                        Image(systemName: "exclamationmark.icloud.fill").accessibilityLabel("No se pudo guardar en el servidor")
                    } else if pendiente {
                        Image(systemName: "icloud.and.arrow.up").accessibilityLabel("Cambios sin subir")
                    }
                    if tarjeta.compartida && dueno == nil { Image(systemName: "person.2.fill").accessibilityLabel("Compartida con la familia") }
                    if let dueno { Label(dueno, systemImage: "person.fill") }
                    if let programa { Image(systemName: programa.tipo.simbolo) }
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white.opacity(0.2), in: .capsule)
            }
            Spacer(minLength: grande ? 18 : 12)
            Text(tarjeta.titulo(programa))
                .font(grande ? .title2.bold() : .title3.bold())
                .lineLimit(1)
            if let socio = tarjeta.numeroSocio, !socio.isEmpty {
                Text(socio)
                    .font(.system(grande ? .title3 : .headline, design: .monospaced).weight(.semibold))
                    .opacity(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(grande ? 22 : 18)
        .frame(maxWidth: .infinity, minHeight: grande ? 200 : 150, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Paleta.degradado(tarjeta.colorEfectivo(programa)))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
        }
        .shadow(color: Color(hexTexto: tarjeta.colorEfectivo(programa)).opacity(0.25), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var iniciales: String {
        let palabras = tarjeta.titulo(programa).split(separator: " ").filter { $0.first?.isLetter == true }
        return String(palabras.prefix(2).compactMap(\.first)).uppercased()
    }
}
