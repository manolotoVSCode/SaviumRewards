import Foundation

/// Fusión de las tarjetas propias locales con lo que llega del servidor. Gana la última edición (`actualizado`);
/// una tarjeta pendiente de subir solo se sustituye si el servidor tiene una versión igual o más reciente.
public enum Fusion {
    public static func aplicar(locales: [Tarjeta], pendientes: Set<UUID>, servidor: [Tarjeta])
        -> (tarjetas: [Tarjeta], pendientes: Set<UUID>) {
        var porId = Dictionary(locales.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var pendientes = pendientes
        for remota in servidor {
            guard let local = porId[remota.id], pendientes.contains(remota.id) else {
                porId[remota.id] = remota
                continue
            }
            if remota.actualizado >= local.actualizado {
                porId[remota.id] = remota
                pendientes.remove(remota.id)
            }
        }
        return (ordenadas(Array(porId.values)), pendientes)
    }

    /// Las tarjetas de la familia se reemplazan enteras en cada descarga: lo que ya no llega
    /// (borrado o vuelto privado) desaparece.
    public static func familia(servidor: [Tarjeta]) -> [Tarjeta] {
        ordenadas(servidor.filter { !$0.borrado })
    }

    public static func ordenadas(_ tarjetas: [Tarjeta]) -> [Tarjeta] {
        tarjetas.sorted { a, b in
            if a.orden != b.orden { return a.orden < b.orden }
            if (a.nombre ?? "") != (b.nombre ?? "") { return (a.nombre ?? "") < (b.nombre ?? "") }
            return a.id.uuidString < b.id.uuidString
        }
    }
}
