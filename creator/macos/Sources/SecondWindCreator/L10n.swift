// All user-facing copy, English and Spanish, in one place.
// House rule: plain words only — the person reading this has never used a
// terminal and never will. No "flash", "image", "GPT", "checksum".
import Foundation

struct L10n {
    static let isSpanish = Locale.preferredLanguages.first?.hasPrefix("es") ?? false

    static func t(_ en: String, _ es: String) -> String { isSpanish ? es : en }

    // --- Welcome ---
    static var appTitle: String { t("Second Wind Creator", "Creador de Second Wind") }
    static var welcomeTitle: String { t("A second wind for this Mac", "Un segundo aire para este Mac") }
    static var welcomeBody: String { t(
        """
        This assistant prepares a USB stick that installs Second Wind: your Mac \
        keeps its familiar feel — the ⌘ shortcuts, the search, the look — but \
        runs Ubuntu, a modern system with security updates until 2029.

        To be very clear: it is not macOS. It is Ubuntu, dressed to feel like \
        your Mac, with no Apple software inside. And the Mac where you use the \
        stick starts from scratch: its disk is completely erased.
        """,
        """
        Este asistente prepara un pendrive que instala Second Wind: tu Mac \
        conserva lo conocido — los atajos ⌘, la búsqueda, la apariencia — pero \
        por dentro corre Ubuntu, un sistema moderno con actualizaciones de \
        seguridad hasta 2029.

        Para ser muy claros: no es macOS. Es Ubuntu, vestido para sentirse como \
        tu Mac, sin software de Apple. Y el Mac donde uses el pendrive parte de \
        cero: su disco se borra por completo.
        """) }
    static var welcomeNeeds: String { t(
        "You'll need: a USB stick of 8 GB or more (it gets erased too), internet, and about half an hour.",
        "Vas a necesitar: un pendrive de 8 GB o más (también se borra), internet y una media hora.") }
    static var start: String { t("Start", "Empezar") }

    // --- The two mandatory locks ---
    static var locksTitle: String { t("Two promises before we begin", "Dos promesas antes de empezar") }
    static var lock1: String { t(
        "I already saved everything I care about from the Mac I'm going to renew (photos, documents) — or there is nothing on it I need.",
        "Ya guardé todo lo que me importa del Mac que voy a renovar (fotos, documentos) — o no hay nada en él que necesite.") }
    static var lock2: String { t(
        "I understand that the Mac where I use this stick will be completely erased, including macOS and everything on it.",
        "Entiendo que el Mac donde use este pendrive quedará borrado por completo, incluido macOS y todo lo que contiene.") }
    static var lockPower: String { t(
        "One more thing for later: when you install, keep that Mac plugged into power.",
        "Un detalle para después: cuando instales, mantén ese Mac conectado a la corriente.") }
    static var locksHint: String { t(
        "Both boxes are required — that's on purpose.",
        "Las dos casillas son obligatorias — es a propósito.") }
    static var continueBtn: String { t("Continue", "Continuar") }
    static var backBtn: String { t("Back", "Atrás") }

    // --- Download ---
    static var downloadTitle: String { t("Getting the pieces", "Buscando las piezas") }
    static var downloadBody: String { t(
        "Downloading the official Ubuntu system (about 6 GB) and Second Wind. Every piece is verified against its official fingerprint. You can close the lid — it resumes.",
        "Descargando el sistema Ubuntu oficial (unos 6 GB) y Second Wind. Cada pieza se verifica contra su huella oficial. Puedes cerrar la tapa — se retoma solo.") }
    static var downloadISO: String { t("Ubuntu system", "Sistema Ubuntu") }
    static var downloadPayload: String { t("Second Wind", "Second Wind") }
    static var verified: String { t("verified ✓", "verificado ✓") }
    static var downloadFailed: String { t(
        "The download stumbled. Check your internet and press Retry — it continues where it stopped.",
        "La descarga tropezó. Revisa tu internet y aprieta Reintentar — sigue donde quedó.") }
    static var retry: String { t("Retry", "Reintentar") }

    // --- Disk picker ---
    static var pickTitle: String { t("Choose the USB stick", "Elige el pendrive") }
    static var pickBody: String { t(
        "Only sticks plugged in from outside appear here — never this Mac's own disk. The one you choose is completely erased.",
        "Aquí solo aparecen pendrives conectados por fuera — nunca el disco de este Mac. El que elijas se borra por completo.") }
    static var pickEmpty: String { t(
        "No stick detected. Plug one in (8 GB or more) and it will appear here.",
        "No se detecta ningún pendrive. Conecta uno (de 8 GB o más) y aparecerá aquí.") }
    static var refresh: String { t("Look again", "Buscar de nuevo") }

    // --- Confirm ---
    static var confirmTitle: String { t("Last confirmation", "Última confirmación") }
    static func confirmBody(_ name: String, _ size: String) -> String { t(
        "Everything on “\(name)” (\(size)) will be erased and replaced by the Second Wind installer.",
        "Todo lo que hay en “\(name)” (\(size)) se borrará y será reemplazado por el instalador de Second Wind.") }
    static var confirmWord: String { t("ERASE", "BORRAR") }
    static func confirmType(_ word: String) -> String { t(
        "Type \(word) to confirm:", "Escribe \(word) para confirmar:") }
    static var confirmGo: String { t("Create the stick", "Crear el pendrive") }
    static var passwordNote: String { t(
        "Your Mac will ask for your password — that's the system giving permission to write the stick.",
        "Tu Mac te pedirá tu contraseña — es el sistema dando permiso para escribir el pendrive.") }

    // --- Writing ---
    static var writingTitle: String { t("Creating your stick", "Creando tu pendrive") }
    static var writingBody: String { t(
        "Several minutes. Don't unplug the stick; you can keep using the Mac.",
        "Son varios minutos. No desconectes el pendrive; puedes seguir usando el Mac.") }
    static var phaseUnmount: String { t("Releasing the stick…", "Liberando el pendrive…") }
    static var phaseISO: String { t("Copying the system…", "Copiando el sistema…") }
    static var phaseSeed: String { t("Adding Second Wind…", "Agregando Second Wind…") }
    static var phaseVerify: String { t("Double-checking everything…", "Revisando que todo quedó bien…") }
    static var phaseEject: String { t("Finishing…", "Terminando…") }
    static var writeFailed: String { t(
        "Something went wrong while writing. The stick may be half-done (nothing else was touched). Unplug it, plug it back in and try again.",
        "Algo falló al escribir. El pendrive puede haber quedado a medias (nada más fue tocado). Desconéctalo, vuelve a conectarlo e intenta de nuevo.") }
    static var authDeclined: String { t(
        "Without your password the stick can't be written. Try again when you're ready.",
        "Sin tu contraseña no se puede escribir el pendrive. Intenta de nuevo cuando quieras.") }

    // --- Done: the rescue card ---
    static var doneTitle: String { t("Your stick is ready 🎉", "Tu pendrive está listo 🎉") }
    static var doneSteps: String { t(
        """
        On the Mac you want to renew:

        1. Plug in this stick.
        2. Plug the Mac into power.
        3. Turn it on HOLDING the Option (⌥) key, next to the space bar.
        4. Choose the yellow disk that says “EFI Boot”.
        5. Answer the four friendly screens (language, keyboard, WiFi, your \
        name). Then it works alone, about half an hour. Don't turn it off.
        """,
        """
        En el Mac que quieres renovar:

        1. Conecta este pendrive.
        2. Conecta el Mac a la corriente.
        3. Enciéndelo MANTENIENDO la tecla Option (⌥), al lado de la barra \
        espaciadora.
        4. Elige el disco amarillo que dice “EFI Boot”.
        5. Responde las cuatro pantallas amables (idioma, teclado, WiFi, tu \
        nombre). Después trabaja solo, una media hora. No lo apagues.
        """) }
    static var rescueTitle: String { t("If anything looks wrong", "Si algo se ve raro") }
    static var rescueBody: String { t(
        "Breathe. Your Mac is fine — these Macs always keep a built-in door back to macOS, and we never touch it. The rescue guide walks you through every path:",
        "Respira. Tu Mac está bien — estos Macs siempre conservan una puerta integrada de vuelta a macOS, y nosotros jamás la tocamos. La guía de rescate te acompaña por cada camino:") }
    static var rescueLink: String { "secondwindformac.com/rescue" }
    static var makeAnother: String { t("Create another stick", "Crear otro pendrive") }
    static var quit: String { t("Close", "Cerrar") }
}
