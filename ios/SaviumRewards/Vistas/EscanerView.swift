import SwiftUI
import Vision
import VisionKit
import RewardsCore

/// Lee el código de la tarjeta física con la cámara (VisionKit). Al primer código reconocido, lo devuelve.
struct EscanerView: View {
    @Environment(\.dismiss) private var cerrar
    let leido: (String, TipoCodigo) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    Escaner { valor, tipo in
                        leido(valor, tipo)
                        cerrar()
                    }
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        Text("Apunta al código de barras o QR de la tarjeta")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .glassEffect(.regular, in: .capsule)
                            .padding(.bottom, 30)
                    }
                } else {
                    ContentUnavailableView("No se puede escanear", systemImage: "camera.badge.ellipsis",
                                           description: Text("Este iPhone no permite leer códigos o la cámara no tiene permiso. Puedes escribir el código a mano."))
                }
            }
            .navigationTitle("Escanear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { cerrar() } }
            }
        }
    }

    static func tipo(_ simbologia: VNBarcodeSymbology, valor: String) -> TipoCodigo {
        switch simbologia {
        case .qr, .microQR: return .qr
        case .ean13: return .ean13
        case .ean8: return .ean8
        case .upce: return Codigos.validar(valor, tipo: .code128) == .valido ? .code128 : .qr
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum:
            return Codigos.validar(valor, tipo: .code39) == .valido ? .code39 : .code128
        case .pdf417, .microPDF417: return .pdf417
        case .aztec: return .aztec
        default:
            return Codigos.validar(valor, tipo: .code128) == .valido ? .code128 : .qr
        }
    }
}

private struct Escaner: UIViewControllerRepresentable {
    let leido: (String, TipoCodigo) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let escaner = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .accurate,
                                                isHighlightingEnabled: true)
        escaner.delegate = context.coordinator
        try? escaner.startScanning()
        return escaner
    }

    func updateUIViewController(_ escaner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ escaner: DataScannerViewController, coordinator: Coordinador) {
        escaner.stopScanning()
    }

    func makeCoordinator() -> Coordinador { Coordinador(leido: leido) }

    @MainActor
    final class Coordinador: NSObject, DataScannerViewControllerDelegate {
        let leido: (String, TipoCodigo) -> Void
        private var hecho = false
        init(leido: @escaping (String, TipoCodigo) -> Void) { self.leido = leido }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                guard !hecho, case .barcode(let codigo) = item, let valor = codigo.payloadStringValue, !valor.isEmpty else { continue }
                hecho = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                leido(valor, EscanerView.tipo(codigo.observation.symbology, valor: valor))
                return
            }
        }
    }
}
