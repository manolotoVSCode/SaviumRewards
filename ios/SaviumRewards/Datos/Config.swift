import Foundation

/// Proyecto de Supabase de Savium Finanzas (tablas `rewards_*`). La clave es pública:
/// la seguridad está en las reglas de acceso (RLS) de cada tabla.
enum Config {
    static let supabaseURL = URL(string: "https://alexhdutnvlxwhziudnr.supabase.co")!
    static let supabaseClave = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsZXhoZHV0bnZseHdoeml1ZG5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc1MTk4NjAsImV4cCI6MjA2MzA5NTg2MH0.5xENkTcPI7cQR3fPG8_zD05E8b0EbfCMtr0HAhmHhzI"
    static let privacidad = URL(string: "https://manolotovscode.github.io/SaviumRewards/#/privacidad")!
}
