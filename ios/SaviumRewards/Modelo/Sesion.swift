import Foundation
import Observation
import Supabase

/// Sesión con correo y código de un solo uso. El registro está cerrado: solo entran correos invitados.
@Observable @MainActor
final class Sesion {
    enum Estado: Equatable { case cargando, fuera, dentro(UUID) }
    private(set) var estado: Estado = .cargando
    private(set) var email: String?
    var mensaje: String?
    private var cierreVoluntario = false

    init() {
        #if DEBUG
        if Demo.activo { estado = .dentro(Demo.yo); email = "manuel@ejemplo.com"; return }
        #endif
        Task { await escuchar() }
    }

    var usuario: UUID? { if case let .dentro(id) = estado { id } else { nil } }

    private func escuchar() async {
        for await (evento, sesion) in supabase.auth.authStateChanges {
            switch evento {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                estado = sesion.map { .dentro($0.user.id) } ?? .fuera
                email = sesion?.user.email
            case .signedOut:
                if case .dentro = estado, !cierreVoluntario {
                    mensaje = String(localized: "Tu sesión ha caducado. Vuelve a entrar con tu correo.")
                }
                cierreVoluntario = false
                estado = .fuera
            default:
                break
            }
        }
    }

    /// Envía el código al correo. Devuelve false si no se pudo (con el motivo en `mensaje`).
    func pedirCodigo(email: String) async -> Bool {
        mensaje = nil
        do {
            try await supabase.auth.signInWithOTP(email: Self.limpiar(email), shouldCreateUser: false)
            return true
        } catch {
            let texto = String(describing: error).lowercased()
            if texto.contains("signup") || texto.contains("not allowed") || texto.contains("otp_disabled") || texto.contains("not found") {
                mensaje = String(localized: "Savium Rewards es solo por invitación. Pide a quien administra tu familia que te invite con este correo.")
            } else if texto.contains("rate") || texto.contains("429") {
                mensaje = String(localized: "Has pedido varios códigos seguidos. Espera un minuto y vuelve a intentarlo.")
            } else {
                mensaje = String(localized: "No se pudo enviar el código. Revisa la conexión y el correo.")
            }
            return false
        }
    }

    func verificar(email: String, codigo: String) async -> Bool {
        mensaje = nil
        do {
            try await supabase.auth.verifyOTP(email: Self.limpiar(email), token: codigo.filter(\.isNumber), type: .email)
            return true
        } catch {
            mensaje = String(localized: "El código no es correcto o ha caducado.")
            return false
        }
    }

    /// Cierra la sesión en este iPhone. No espera al evento de Supabase: el estado pasa a «fuera» aunque el
    /// aviso no llegue (sin conexión, o en el modo de demostración, que no escucha a Supabase).
    func cerrar() async {
        cierreVoluntario = true
        try? await supabase.auth.signOut(scope: .local)
        estado = .fuera
        email = nil
    }

    /// Se llama tras eliminar la cuenta en el servidor.
    func olvidar() async { await cerrar() }

    /// Entrada con contraseña: para quien ya la tiene (el titular, por Savium Finanzas) y para la cuenta de
    /// revisión de Apple, que no puede recibir códigos por correo.
    func entrar(email: String, clave: String) async -> Bool {
        mensaje = nil
        do {
            try await supabase.auth.signIn(email: Self.limpiar(email), password: clave)
            return true
        } catch {
            mensaje = String(localized: "No se pudo entrar. Revisa el correo y la contraseña.")
            return false
        }
    }

    static func limpiar(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
