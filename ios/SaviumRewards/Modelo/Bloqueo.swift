import Foundation
import LocalAuthentication
import Observation
import RewardsCore

/// Face ID al abrir y al volver tras el plazo elegido, como en Savium Finanzas. Usa la autenticación del
/// dispositivo (Face ID y, si falla, el código del iPhone), así que nunca deja a nadie fuera; en un iPhone sin
/// Face ID ni código no bloquea.
@Observable @MainActor
final class Bloqueo {
    private static let claveActivo = "rewards.faceid"
    private static let clavePlazo = "rewards.faceid.plazo"
    private var regla: ReglaBloqueo
    var bloqueado: Bool { regla.bloqueado }
    let disponible: Bool
    private(set) var activo: Bool
    private(set) var plazo: PlazoBloqueo

    init() {
        var error: NSError?
        let puede = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        let preferido = UserDefaults.standard.object(forKey: Self.claveActivo) as? Bool ?? true
        let plazoGuardado = PlazoBloqueo(rawValue: UserDefaults.standard.string(forKey: Self.clavePlazo) ?? "") ?? .alInstante
        disponible = puede
        activo = preferido
        plazo = plazoGuardado
        #if DEBUG
        let demo = Demo.activo
        #else
        let demo = false
        #endif
        regla = ReglaBloqueo(puedeAutenticar: puede && preferido && !demo, plazo: plazoGuardado)
    }

    /// Desde Ajustes. Al activarlo no se bloquea en ese momento, sino al próximo arranque o regreso.
    func cambiarActivo(_ valor: Bool) {
        activo = valor
        UserDefaults.standard.set(valor, forKey: Self.claveActivo)
        regla = ReglaBloqueo(puedeAutenticar: disponible && valor, plazo: plazo)
        regla.desbloqueado()
    }

    func cambiarPlazo(_ valor: PlazoBloqueo) {
        plazo = valor
        UserDefaults.standard.set(valor.rawValue, forKey: Self.clavePlazo)
        regla = ReglaBloqueo(puedeAutenticar: disponible && activo, plazo: valor)
        regla.desbloqueado()
    }

    /// true si entró.
    func desbloquear() async -> Bool {
        guard regla.bloqueado else { return true }
        let ok = (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication,
                                                        localizedReason: String(localized: "Entrar en Savium Rewards"))) ?? false
        if ok { regla.desbloqueado() }
        return ok
    }

    /// Acaba de iniciar sesión con su correo: no se le pide Face ID encima.
    func recienAutenticado() { regla.desbloqueado() }

    func enSegundoPlano(_ ahora: Date = .now) { regla.enSegundoPlano(ahora) }
    func alVolver(_ ahora: Date = .now) { regla.alVolver(ahora) }
}
