# Etapa 1 — hoja de ruta

Pendientes ordenados por impacto, sobre la base ya montada en la Etapa 0:

1. **Instalar dependencias que hoy solo se configuran**: Toshy (teclado) y
   Ulauncher (Spotlight) deben instalarse automáticamente si faltan, con
   versión pineada, para que el instalador funcione en equipos vírgenes.
2. **Modo claro/oscuro conmutable**: hoy se instala MacTahoe-Light y Dark;
   falta que el interruptor de Ubuntu cambie tema+iconos+shell juntos
   (posible con un ajuste de `color-scheme` + user-theme dinámico).
3. **Apps estilo Mac** (módulo 70): habilitar Flatpak, y proponer paquete
   básico: visor de fotos, música, OnlyOffice (look más Mac que LibreOffice).
4. **Tema de Firefox**: el `tweaks.sh -f` de MacTahoe con adaptación al perfil
   snap (`~/snap/firefox/common/.mozilla`).
5. **Pantalla de acceso (GDM)** con `tweaks.sh -g`, con respaldo propio del
   recurso del sistema (riesgo medio: afecta al login).
6. **i18n inglés**: `lib/i18n/en.sh` (las claves ya están centralizadas) y
   README en inglés.
7. **Detección de modelo Mac por DMI** para activar arreglos específicos
   (cada modelo tiene sus mañas: sensores, WiFi, cámara).
8. **Soporte GNOME 47/48** (Ubuntu 24.10+/26.04) re-pineando `versions.lock`.
9. **GUI del instalador** (Zenity/GTK) — hoy el TUI whiptail cumple.
10. **Decisión de negocio**: liberar (MIT ya lo permite) vs. vender
    empaquetado; el código propio es MIT y lo GPL se descarga aparte, así que
    ambas puertas quedan abiertas.

# Etapa 2 — "la Mac nueva en un pendrive"

Visión: un usuario no técnico, aún en macOS, crea un USB que instala
Ubuntu + MacConLinux de una vez, sin ver una terminal jamás.

- **USB autoinstalable**: ISO oficial de Ubuntu + semilla `autoinstall`
  (subiquity/NoCloud, volumen `CIDATA`): instalación 100 % desatendida que
  deja MacConLinux aplicado antes del primer inicio de sesión. No se
  redistribuye la ISO (sin hosting de 3 GB ni problemas legales).
- **Creador del pendrive en macOS**: primero guía web + balenaEtcher; meta:
  app propia ("Crea tu Mac nueva en 3 clics"). Arranque con la tecla Option.
- **Decisiones clave a resolver**: borrar macOS vs. dual-boot (UX de
  advertencia fortísima), cifrado de disco, detección de modelo, prueba real
  con pendrive físico en el equipo de referencia.
- La Etapa 0 ya lo facilita: instalador idempotente, modo desatendido
  (`--si`) y módulos que detectan el hardware.
