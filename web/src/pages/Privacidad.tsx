import { useState } from "react";

/** Política de privacidad (enlazada desde la App Store y desde la app). Español e inglés. */
export function Privacidad() {
  const [ingles, setIngles] = useState(() => !navigator.language.toLowerCase().startsWith("es"));
  return (
    <main className="mx-auto max-w-2xl space-y-4 px-6 py-12 leading-relaxed">
      <button className="text-sm text-savium" onClick={() => setIngles(!ingles)}>{ingles ? "Español" : "English"}</button>
      {ingles ? (
        <>
          <h1 className="text-3xl font-bold">Savium Rewards — Privacy Policy</h1>
          <p className="text-sm opacity-60">Last updated: October 13, 2026</p>
          <p>Savium Rewards keeps your family's loyalty cards in one place. Access is by invitation only.</p>
          <h2 className="text-xl font-semibold">What we store</h2>
          <ul className="list-disc space-y-1 pl-6">
            <li>Your email address and the name you choose, to sign you in and show you to your family.</li>
            <li>The cards you add: program, member number, barcode content, balance, dates and notes.</li>
            <li>The time of your last sync, so the family administrator can see the app is working.</li>
          </ul>
          <h2 className="text-xl font-semibold">Who can see it</h2>
          <p>Your cards are private unless you mark them as shared; shared cards are visible to the members of your family only. The administrator sees counts, never the content of private cards. We do not sell data, show ads or track you, and we never store card passwords, PINs or payment card numbers.</p>
          <h2 className="text-xl font-semibold">Where it is stored</h2>
          <p>Data is stored with Supabase (database and sign-in) and a copy is kept on your iPhone so the app works offline. The camera is used only to read card barcodes; images are not saved or sent.</p>
          <h2 className="text-xl font-semibold">Deleting your data</h2>
          <p>You can delete your account in the app (Settings → Delete my account). It deletes all your cards, including shared ones.</p>
          <h2 className="text-xl font-semibold">Contact</h2>
          <p>manoloto@gmail.com</p>
        </>
      ) : (
        <>
          <h1 className="text-3xl font-bold">Savium Rewards — Política de privacidad</h1>
          <p className="text-sm opacity-60">Última actualización: 13 de octubre de 2026</p>
          <p>Savium Rewards reúne las tarjetas de fidelidad de tu familia en un solo sitio. El acceso es solo por invitación.</p>
          <h2 className="text-xl font-semibold">Qué guardamos</h2>
          <ul className="list-disc space-y-1 pl-6">
            <li>Tu correo y el nombre que elijas, para iniciar sesión y mostrarte a tu familia.</li>
            <li>Las tarjetas que añades: programa, número de socio, contenido del código, saldo, fechas y notas.</li>
            <li>La hora de tu última sincronización, para que quien administra la familia vea que la app funciona.</li>
          </ul>
          <h2 className="text-xl font-semibold">Quién lo ve</h2>
          <p>Tus tarjetas son privadas salvo que las marques como compartidas; las compartidas solo las ven los miembros de tu familia. Quien administra ve conteos, nunca el contenido de las tarjetas privadas. No vendemos datos, no mostramos publicidad ni hacemos seguimiento, y nunca guardamos contraseñas, NIP ni números de tarjetas de pago.</p>
          <h2 className="text-xl font-semibold">Dónde se guarda</h2>
          <p>Los datos se guardan en Supabase (base de datos e inicio de sesión) y una copia en tu iPhone para que la app funcione sin conexión. La cámara solo se usa para leer el código de las tarjetas; las imágenes no se guardan ni se envían.</p>
          <h2 className="text-xl font-semibold">Borrar tus datos</h2>
          <p>Puedes eliminar tu cuenta desde la app (Ajustes → Eliminar mi cuenta). Se borran todas tus tarjetas, también las compartidas.</p>
          <h2 className="text-xl font-semibold">Contacto</h2>
          <p>manoloto@gmail.com</p>
        </>
      )}
    </main>
  );
}
