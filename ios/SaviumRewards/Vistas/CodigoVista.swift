import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import RewardsCore

/// Dibuja el código de una tarjeta. Los 2D y Code 128 con Core Image; EAN, UPC y Code 39 con `Barras`.
struct CodigoVista: View {
    let valor: String
    let tipo: TipoCodigo

    var body: some View {
        Group {
            if let modulos = Barras.modulos(valor, tipo: tipo) {
                // Zona de silencio de 10 módulos a cada lado: sin ella algunos lectores de caja fallan.
                Canvas { ctx, tamano in
                    let margen = 10
                    let ancho = tamano.width / CGFloat(modulos.count + 2 * margen)
                    for (i, barra) in modulos.enumerated() where barra {
                        ctx.fill(Path(CGRect(x: CGFloat(i + margen) * ancho, y: 0, width: ancho + 0.3, height: tamano.height)), with: .color(.black))
                    }
                }
                .frame(height: 110)
            } else if let imagen = Self.imagen(valor, tipo: tipo) {
                Image(uiImage: imagen)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: tipo == .code128 ? 110 : (tipo == .pdf417 ? 130 : 240))
            } else {
                Label("No se puede dibujar este código", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.white, in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityLabel(Text("Código \(String(localized: tipo.nombre)): \(valor)"))
    }

    static func imagen(_ valor: String, tipo: TipoCodigo) -> UIImage? {
        let datos = Data(valor.utf8)
        let salida: CIImage?
        switch tipo {
        case .qr:
            let f = CIFilter.qrCodeGenerator(); f.message = datos; f.correctionLevel = "M"; salida = f.outputImage
        case .pdf417:
            let f = CIFilter.pdf417BarcodeGenerator(); f.message = datos; salida = f.outputImage
        case .aztec:
            let f = CIFilter.aztecCodeGenerator(); f.message = datos; salida = f.outputImage
        case .code128:
            guard let ascii = valor.data(using: .ascii) else { return nil }
            let f = CIFilter.code128BarcodeGenerator(); f.message = ascii; f.quietSpace = 0; salida = f.outputImage
        default:
            salida = nil
        }
        guard let salida else { return nil }
        let escalada = salida.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = CIContext().createCGImage(escalada, from: escalada.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
