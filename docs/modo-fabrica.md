# Modo de fábrica (diseño)

Documento de análisis y diseño. No describe código ya escrito: describe el flujo actual y propone
un modo de fábrica para un reacondicionador (por ejemplo Reuse) que prepara varios Macs y los vende.
Todo lo que aquí se afirma sobre el estado actual tiene su referencia `archivo:línea`; lo que no se
pudo confirmar desde el repositorio queda marcado como "a verificar en el Air".

Leyenda de la clasificación de cada módulo:

- **SISTEMA**: necesita root, toca paquetes, drivers, servicios o archivos en `/etc`, `/usr`, `/opt`, `/var`.
- **USUARIO**: `gsettings`/`dconf` del usuario, `~/.config`, `~/.local`, extensiones GNOME por usuario, Toshy por usuario, autostart.
- **MIXTO**: hace las dos cosas.

---

## 1. Mapa del flujo actual

### 1.1 Cadena de ejecución, en orden

| # | Archivo | Qué hace |
|---|---|---|
| 1 | `usb/seed/user-data` | Semilla de autoinstall de Ubuntu Desktop 24.04 (volumen `CIDATA`, cloud-init NoCloud). Deja interactivas solo `locale`, `keyboard`, `network`, `identity` (`usb/seed/user-data:15-19`), y automatiza el resto. |
| 2 | `usb/seed/user-data` `early-commands` | Guardas P0 antes de tocar disco: rechaza máquinas no Mac por vendor DMI (`:47-55`), rechaza Macs con chip T2 (`:61-76`), exige disco interno de Apple (`:81-94`). QEMU está permitido para el banco de pruebas. |
| 3 | `usb/seed/user-data` `storage` | Layout `direct` (borra el disco), con `match` solo a discos `APPLE*` o `QEMU*` (`:98-103`). |
| 4 | `usb/seed/user-data` `late-commands` | (a) instala `curl` y `git` best-effort (`:130`); (b) instala **offline** el driver WiFi `wl` de Broadcom precompilado y ajusta initramfs (`:142-191`); (c) fija el kernel GA 6.8 y purga el HWE (`:203-224`); (d) copia el payload a `/target/usr/local/share/second-wind`, instala el firstboot en `/etc/skel/.config/autostart` y en el home de cada usuario creado (`:227-247`). |
| 5 | `usb/firstboot/second-wind-firstboot.sh` | Autostart al primer inicio de sesión. Espera internet (`:90-98`), silencia ventanas de Ubuntu (`:35-39`, `:99-107`), y lanza `install.sh --firstboot` en modo gráfico si hay zenity/DISPLAY (`:137-160`) o en terminal como respaldo (`:162-189`). Deja armado el autostart hasta que `install.sh` termina OK (`:21-24`, `:147-154`). |
| 6 | `install.sh` | Orquesta. Fase de preguntas (`:70-76`), luego `00-preflight` y `10-backup` en el shell principal (`:86-87`), luego el arreglo `MODULES` (`:89-98`) y el bucle que corre cada módulo en un subshell aislado (`:123-136`). |
| 7 | `modules/NN-*.sh` | El trabajo real (ver tabla 1.2). |
| 8 | `bin/second-wind-experience` | Interruptor del Mac Experience (trial / activo / apagado) y activación de licencia Lemon. Arranca en trial con reloj de 30 días (`:195-229`). |

### 1.2 Clasificación por módulo

| Módulo | Trabajo | Tipo | Evidencia |
|---|---|---|---|
| `00-preflight.sh` | Chequeos (distro, GNOME, Wayland), instala `curl`+`git` con sudo, fija zona horaria, detecta dock/toshy, mide espacio en `$HOME`. | MIXTO | distro/GNOME `:10-15`; sesión Wayland del usuario `:19-22`; `apt-get install` con sudo `:31-35`; `timedatectl` `:47-57`; espacio `$HOME` `:59-60`; `systemctl --user` `:62-66` |
| `10-backup.sh` | Respaldo pristino del estado actual del usuario (dconf, `~/.config/gtk-*`, autostart, GDM, valores previos). | USUARIO | `dconf dump /` `:15`; `~/.config/gtk-*` `:19-20`; `$SW_BACKUP` en `$HOME/.local/state` (`lib/common.sh:10`) |
| `15-engines.sh` | Instala motores: WiFi Broadcom (`broadcom-sta-dkms`), headers, `gir1.2-adw-1`, Ulauncher (.deb), y el **servicio de sistema** `second-wind-wl-guard`. Oculta la entrada de Ulauncher a nivel usuario. | MIXTO (casi todo SISTEMA) | apt `:75`, `:92`, `:135-136`; instala `/usr/local/sbin/second-wind-wl-guard` `:109`; unidad systemd de sistema `:110-127`; oculta `.desktop` en `~/.local/share/applications` `:164-170` |
| `20-look.sh` | Tema MacTahoe (GTK + shell), iconos, cursores, fondos y fuente Inter. Todo en el home del usuario. | USUARIO | clone `:6-9`; `~/.themes` `:32-67`; `~/.local/share/backgrounds` `:75-84`; `~/.local/share/icons` `:86-91`; `~/.local/share/fonts` `:94-104`; `gsettings` `:111-131` |
| `30-extensions.sh` | Instala y habilita extensiones GNOME a nivel usuario (User Themes, Blur my Shell, Xremap, Logo Menu) y la extensión propia `secondwind-panel`. Escribe dconf. | USUARIO | `ext_install_pinned` `:9-16`; extensión propia `:22-31`; `dconf_track` `:35`, `:52-59` (sin sudo) |
| `32-toshy.sh` | Instala Toshy (motor de teclado ⌘). Crea un dropin sudoers temporal (sistema) y luego instala Toshy dentro del home del usuario. | MIXTO | dropin sudoers `:38-42`, `:107`; instalador Toshy `:62-88`; oculta entradas en `~/.local/share/applications` `:103-104` |
| `35-dock.sh` | Apariencia del Dock (gsettings, dash-to-dock). | USUARIO | `:12-23` |
| `40-panel.sh` | Barra superior y comportamiento de ventanas (gsettings). | USUARIO | `:5-11` |
| `45-keyboard.sh` | Atajos ⌘Tab y limpieza del motor Toshy: borra el autostart del tray en `~/.config`, habilita servicios de usuario, edita `~/.config/toshy/toshy_config.py`. | USUARIO | gsettings `:8-13`; borra `~/.config/autostart/Toshy_Tray.desktop` `:42-52`; `systemctl --user enable` `:55`; edita config Toshy `:64-87` |
| `47-power-defaults.sh` | Preferencias de energía (gsettings puros). | USUARIO | `:14-31` |
| `50-spotlight.sh` | Configura Ulauncher (tema, settings, autostart en `~/.config/ulauncher` y `~/.config/autostart`) y el atajo ⌘Espacio. | USUARIO | `:18-48`; gsettings/atajo `:58-59` |
| `55-browsers.sh` | Tema de Firefox, flags VA-API de Chrome, preferencias de Chrome en el home, y autostart de `second-wind-titlebars`. | USUARIO | perfiles Firefox en `$HOME` `:19-40`; `.desktop` local `:46-58`; `~/.config/google-chrome/.../Preferences` `:62-101`; autostart `:109-128` |
| `60-hardware.sh` | `mbpfan`, `i965-va-driver`, `/etc/modprobe.d/secondwind-hid_apple.conf`, cámara FaceTime HD (DKMS + firmware en `/usr/lib/firmware`) y ajuste de autologin en `/etc/gdm3/custom.conf`. | SISTEMA | apt `:31-37`, `:43`; `/etc/modprobe.d` `:46-59`; DKMS + firmware `:62-116`; autologin `:119-126` |
| `62-power.sh` | Hibernación: agranda swap, fija `resume=` en GRUB e initramfs, políticas de tapa en systemd. | SISTEMA | swap `:39-54`; GRUB/initramfs `:65-75`; sleep/logind `:78-86` |
| `65-gdm.sh` | Tema del login (GDM): reemplaza `gnome-shell-theme.gresource` de Yaru y ajusta `greeter.dconf-defaults`. | SISTEMA | `:31-46` |
| `70-apps.sh` | Instala la tienda Second Wind (`.desktop`, ícono) en el home, precarga íconos por red y la fija al dock. | USUARIO | `~/.local/share` `:19-49`; prefetch `:55-56`; `favorite_add` `:59` |
| `75-news.sh` | Timer de usuario semanal (noticias y nudge de apoyo de 30 días). | USUARIO | estado en `$HOME/.local/state` `:19-25`; unidades `--user` `:106-127` |
| `76-experience.sh` | Reloj del trial del Mac Experience (timer de usuario diario). | USUARIO | estado en `$HOME` `:12-24`; unidades `--user` `:27-50` |
| `80-updater.sh` | Timer de usuario semanal del actualizador. | USUARIO | `:13-38` |
| `85-quiet.sh` | Silencia el asistente de primer inicio y el Software Updater, con marcadores por usuario. | USUARIO | `~/.config/gnome-initial-setup-done` `:16-21`; override de `update-notifier` en `~/.config/autostart` `:27-38` |
| `90-postlogin.sh` | Verificación única al siguiente inicio de sesión (autostart que se autoborra). | USUARIO | `$HOME/.local/state/.../postlogin.sh` `:10-43`; autostart `:47-49` |

Observaciones clave para el modo de fábrica:

1. Casi todos los módulos "de experiencia" (20, 30, 32, 35, 40, 45, 47, 50, 55, 70, 75, 76, 80, 85, 90) escriben en el **home del usuario**. Si se borra el usuario técnico, todo eso se va con él.
2. Casi todo el "trabajo duro" e irreversible (15, 60, 62, 65) es **SISTEMA** y sobrevive al borrado del usuario.
3. El manifiesto de cambios (`lib/manifest.py`, `lib/common.sh:12`) vive en `$HOME/.local/state/second-wind/manifest.json`. Es decir, hoy el registro de los cambios **de sistema** también vive en el home del usuario. Esto es un problema directo para el modo de fábrica (ver 3).

---

## 2. Diseño del "modo de fábrica"

### 2.0 Idea general

Dos fases, separadas por un marcador de sistema:

- **Fase A (fábrica, una vez, con internet del taller)**: instalar Ubuntu con una semilla "de fábrica", crear un usuario técnico temporal, y correr la conversión **solo en su parte SISTEMA**. Al final, el técnico corre "Preparar para entrega" y el equipo queda apagado.
- **Fase B (comprador, al primer encendido)**: GNOME Initial Setup crea la cuenta del comprador, y al primer inicio de sesión se corre **solo la parte USUARIO** de la conversión (rápida). El Mac Experience ya está activo por la licencia OEM.

Marcadores de sistema propuestos (root, en `/etc/second-wind/`):

- `/etc/second-wind/factory` : existe durante toda la fase de fábrica (lo escribe un `late-command` de la semilla de fábrica).
- `/etc/second-wind/system-done` : lo escribe el instalador cuando termina la parte SISTEMA; su presencia hace que la fase de usuario salte los módulos de sistema.
- `/etc/second-wind/license-oem` : licencia firmada, escrita en la entrega (ver sección 4).
- `/etc/second-wind/manifest.json` : manifiesto de los cambios de SISTEMA (nuevo; ver 3).

### 2.a Instalación sin preguntas al técnico

Semilla de fábrica (una variante de `usb/seed/user-data`, generada por `scripts/make-usb.sh --factory`):

- Dejar interactivo solo lo mínimo: `locale`, `keyboard`, `network` (el técnico elige el WiFi del taller o usa cable). Quitar `identity` de `interactive-sections` (hoy está en `usb/seed/user-data:19`).
- Fijar `identity` no interactiva a un **usuario técnico temporal**, por ejemplo `username: technician`, con una contraseña conocida del taller (o autologin solo durante la preparación). Nunca el nombre del comprador.
- Añadir un `late-command` que cree `/target/etc/second-wind/factory` para que el firstboot sepa que está en fábrica.
- Mantener intactas las guardas P0 (`user-data:47-94`, `:98-103`): sirven igual en fábrica y protegen de borrar el disco equivocado entre muchos Macs.

Alternativa válida y un poco más limpia: dejar la semilla totalmente no interactiva fijando también `locale`, `keyboard` y `network` (valores del taller), de modo que el técnico solo conecte el pendrive y espere. Recomiendo dejar `network` interactivo porque el WiFi del taller conviene elegirlo en el momento; el resto se puede automatizar.

### 2.b Correr la parte de SISTEMA una vez, en fábrica

`install.sh` necesita dos modos nuevos, además del actual:

- `--factory` (parte SISTEMA): corre `00-preflight`, `10-backup` (respaldo del técnico, opcional), y SOLO los módulos SISTEMA: `15-engines`, `60-hardware`, `62-power`, `65-gdm`. Al terminar, escribe `/etc/second-wind/system-done` (con `sudo`).
- `--user-only` (parte USUARIO, para el comprador): corre `00-preflight` (chequeos), `10-backup` (respaldo del comprador), y los módulos USUARIO: `20-look`, `30-extensions`, `32-toshy`, `35-dock`, `40-panel`, `45-keyboard`, `47-power-defaults`, `50-spotlight`, `55-browsers`, `70-apps`, `75-news`, `76-experience`, `80-updater`, `85-quiet`, `90-postlogin`. Al terminar, escribe el sello de éxito en el home del comprador (el actual `firstboot-done`).

El firstboot (`usb/firstboot/second-wind-firstboot.sh`) pasa a decidir la fase:

- Si existe `/etc/second-wind/factory` y NO existe `system-done`, corre `install.sh --factory` (Fase A).
- Si existe `system-done`, corre `install.sh --user-only` (Fase B).
- Sin marcadores, se comporta como hoy (compatibilidad con las máquinas ya instaladas).

Un detalle importante del particionado de módulos: `32-toshy` es MIXTO y hoy es el módulo más lento
(`install.sh:115-118` estima 170 s). En Fase B, Toshy tendría que reinstalarse para el comprador porque
vive en el home. Dos caminos:

- **Camino simple (recomendado para la v1)**: en Fase A, instalar Toshy una vez con el usuario técnico y, en la entrega, **promover** su instalación a nivel sistema (Toshy instala servicios de usuario, pero su motor y su configuración pueden pre-copiarse a `/etc/skel` y a `/usr/local`). Esto es lo que hay que validar en el Air: si Toshy permite una instalación de sistema o si basta con conservar su `~/.config/toshy` y `~/.local/bin` en `/etc/skel`.
- **Camino de respaldo**: aceptar que la Fase B reinstale Toshy y por tanto dure más de 2 minutos. El objetivo "menos de 2 min" se cumple para el resto de la conversión; Toshy es el único bloque que lo rompe.

### 2.c "Preparar para entrega"

Un comando nuevo (un botón en la app Second Wind, o `second-wind-factory-deliver` en un terminal) que:

1. Cierra la Fase B para el comprador: confirma que `/etc/second-wind/system-done` existe y deja la licencia OEM en `/etc/second-wind/license-oem`.
2. Programa la limpieza para el próximo arranque con una unidad de sistema, por ejemplo `second-wind-factory-reset.service`, ordenada `Before=display-manager.service`. Motivo: no se puede borrar de forma segura el usuario con el que se está logueado; hacerlo en el arranque siguiente, antes de que arranque GDM, evita condiciones de carrera.
3. La unidad de limpieza hace, ya como root y sin sesión de usuario:
   - **Borra el usuario técnico y su home**: `userdel -r technician` (o `deluser --remove-home technician`). Con eso desaparecen historial de shell, `~/.config`, `~/.local`, autostart, servicios de usuario, y el manifiesto del técnico.
   - **Redes WiFi del taller**: borra los perfiles en `/etc/NetworkManager/system-connections/` (ahí guarda NetworkManager las redes con clave). Dejar la máquina sin redes guardadas.
   - **Logs con datos del taller**: borra `/var/log/second-wind-wifi.log` y los logs propios (`/home/*/.local/state/second-wind/logs`). Aplica `journalctl --rotate` y `journalctl --vacuum-time=1s` para el journal. Nota honesta: los logs de `apt`/`dpkg` (`/var/log/apt`, `/var/log/dpkg.log`) son de sistema y borrarlos a mano es frágil; se pueden truncar o se acepta dejarlos (no contienen el nombre del comprador). Ver riesgos.
   - **Machine-id**: trunca `/etc/machine-id` y `/var/lib/dbus/machine-id`. systemd los regenera en el próximo arranque (`systemd-machine-id-setup`). Esto es lo que pide el diseño, y no rompe la licencia porque la licencia OEM NO se ata al machine-id.
   - **Claves SSH de host**: borra `/etc/ssh/ssh_host_*` (si existen) para que se regeneren. En Ubuntu Desktop 24.04 el servidor OpenSSH no viene instalado por defecto, así que normalmente no habrá nada que borrar; si existe, se pueden regenerar con `ssh-keygen -A`.
   - **Hostname**: lo deja neutro (`second-wind`), el mismo que fija la semilla (`usb/seed/user-data:27`).
   - **Respaldo pristino del técnico**: borra `$HOME/.local/state/second-wind/backup` (se va con el home; si se movió a un lugar de sistema, se borra aparte).
   - **Sudoers temporales**: borra `/etc/sudoers.d/zz-second-wind-gui` y `/etc/sudoers.d/zz-second-wind-toshy` si quedaron (normalmente ya se limpian: `lib/gui.sh:62-66`, `modules/32-toshy.sh:107`).
   - **Re-armado del firstboot del comprador**: el autostart ya está en `/etc/skel/.config/autostart/second-wind-firstboot.desktop` (lo instaló `user-data:237-238`), de modo que la cuenta nueva del comprador lo recibe automáticamente. Verificar que `/etc/skel` no arrastre restos del técnico.
   - **Apagado**: `systemctl poweroff` al terminar la limpieza. El equipo queda apagado, listo para empacar y vender.

Implementación recomendada del paso "programa y apaga": el comando `personalizar entrega` escribe el marcador `factory-deliver-pending`, habilita la unidad de limpieza y hace `systemctl poweroff`. En el siguiente encendido arranca la limpieza (antes de GDM), hace su trabajo y vuelve a apagarse sola (o arranca directo al asistente del comprador). Validar en el Air que el orden `Before=display-manager.service` se respeta y que un `poweroff` dentro de una unidad `Type=oneshot` no deja el equipo en un estado raro.

### 2.d El comprador enciende

Estado buscado: la máquina no tiene usuarios (el técnico fue borrado) y GNOME Initial Setup corre en
modo "usuario nuevo": pide idioma, teclado, WiFi y crea la cuenta del comprador. Al primer inicio de
sesión de esa cuenta nueva, el autostart (heredado de `/etc/skel`) lanza el firstboot, que por el
marcador `system-done` corre solo `install.sh --user-only`. Mac Experience queda activa porque el
verificador lee `/etc/second-wind/license-oem`.

**GNOME Initial Setup: lo que se puede confirmar desde el repositorio y lo que no.**

- Confirmado desde el repositorio: en Ubuntu 24.04 existe el modo **por usuario** de gnome-initial-setup. `modules/85-quiet.sh:12-21` documenta que su servicio de primer inicio corre solo mientras falta `~/.config/gnome-initial-setup-done` (condición `ConditionPathExists=!...`). Es exactamente lo que Second Wind silencia hoy, y es la razón por la que el comprador de una instalación normal no ve el asistente.
- **A verificar en el Air** (no se puede confirmar desde el repositorio): que GDM, con la máquina **sin ningún usuario**, lance gnome-initial-setup en modo **sistema** (el que incluye la página para crear la primera cuenta). Los puntos concretos a comprobar en el Air:
  1. La clave `InitialSetupEnable` en `/etc/gdm3/custom.conf` (sección `[daemon]`) y su valor por defecto en Ubuntu 24.04.
  2. El archivo de configuración de proveedor `/var/lib/gnome-initial-setup/vendor.conf` y su comportamiento de re-armado (`InitialSetupEnable`). Ver qué marcadores deben faltar (por ejemplo `/var/lib/gnome-initial-setup/*done*`) para que el asistente vuelva a mostrarse.
  3. Que tras `userdel` del técnico, al arrancar con 0 usuarios, GDM efectivamente muestre el asistente con la página de cuenta y que la cuenta creada quede con la contraseña correcta y en el grupo `sudo`.
  4. Que `/etc/skel` (con el autostart de Second Wind) se copie a esa cuenta nueva.
- **Respaldo si el modo sistema no coopera**: Ubuntu trae un modo OEM (`oem-config`/`oem-config-prepare`). Es la vía soportada por Ubuntu para exactamente este caso (el técnico prepara y el usuario final completa). Si el modo usuario nuevo de GNOME Initial Setup no resulta fiable en el Air, la recomendación de respaldo es usar el flujo OEM de Ubuntu para la creación de la cuenta del comprador, manteniendo intacta la partición SISTEMA/USUARIO de Second Wind.

---

## 3. Cambios concretos por archivo

Convención: "Taller" significa que se puede probar aquí (tests bash con stubs, o la VM QEMU). "Air"
significa que solo se puede probar en el MacBook Air real.

### 3.1 Semilla y creación del pendrive

- **Modificar `scripts/make-usb.sh`**: añadir `--factory`. En modo fábrica, generar `user-data` desde una
  variante (nueva carpeta `usb/seed/factory/` con su propio `user-data` y `meta-data`, o un `sed` dirigido)
  que (a) quite `identity` de `interactive-sections`, (b) fije la identidad al usuario técnico, (c) agregue
  un `late-command` que cree `/target/etc/second-wind/factory` y siembre `/target/etc/skel`.
  - Riesgo: duplicar la semilla puede desincronizar las guardas P0 y el bloque de WiFi offline. Mitigación: mantener las guardas en un archivo común y que la variante de fábrica lo incluya; o generar la variante con un `include` textual validado por test.
  - Probar en Taller: un test que compare las `early-commands` y `storage` de la semilla normal y la de fábrica y exija que sean idénticas.
  - Probar en Air: arranque real del pendrive de fábrica.

- **Nuevo `usb/seed/factory/user-data`** (o el `sed` en `make-usb.sh`): ver arriba.

### 3.2 Instalador

- **Modificar `install.sh`**:
  - Nuevos flags `--factory` y `--user-only`, con el mismo patrón de parseo actual (`install.sh:46-62`).
  - Definir el conjunto SISTEMA y el conjunto USUARIO, y construir `MODULES` según el modo. Mantener el
    arreglo actual como default (compatibilidad).
  - En `--factory`, al terminar OK, escribir `/etc/second-wind/system-done` (con `sudo`) y NO pedir logout.
  - La fase de preguntas (`install.sh:70-76`) se salta también en `--factory` y `--user-only`.
  - Actualizar `MOD_SECONDS` (`install.sh:115-118`) para los dos subconjuntos.
  - Riesgo: romper el flujo normal. Mitigación: los modos nuevos son aditivos; un test que corra la lógica de armado de `MODULES` en los tres modos y verifique cobertura y no solapamiento.
  - Probar en Taller: test estático (como `tests/gui/test_toshy_wired.sh`, que ya evalúa el bloque `MODULES=()` de `install.sh`) que verifique que todo módulo cae en exactamente uno de {SISTEMA, USUARIO} y que no falta ninguno.
  - Probar en Air: la corrida real.

### 3.3 Firstboot

- **Modificar `usb/firstboot/second-wind-firstboot.sh`**: elegir la fase según los marcadores de
  `/etc/second-wind/`. En `--factory` no aplica el bucle de "esperar WiFi del comprador" igual que hoy,
  pero sí necesita red (el taller la tiene). Mantener el respaldo a terminal.
  - Riesgo: la lógica de reintento actual usa el sello por usuario (`STAMP` en `$HOME`, `:14`); en fábrica el home es el del técnico y en la entrega se borra, así que el sello no sirve como memoria entre fases. Usar el marcador de sistema como fuente de verdad de la fase.
  - Probar en Taller: `tests/gui/test_firstboot_flow.sh` ya existe; extender con aserciones de que el script lee los marcadores y llama al modo correcto de `install.sh`.
  - Probar en Air: corrida real en cada fase.

### 3.4 Manifiesto de sistema (nuevo, importante)

- **Modificar `lib/common.sh` / `lib/manifest.py`**: hoy el manifiesto vive en el home
  (`lib/common.sh:12`). Añadir un **manifiesto de sistema** en `/etc/second-wind/manifest.json` (root)
  para los cambios de sistema (paquetes apt, DKMS, archivos en `/etc`, `/usr`). El manifiesto de usuario
  sigue en el home para lo de usuario. `uninstall.sh` debe leer ambos.
  - Riesgo: hoy `uninstall.sh` (`:42-47`, `:71-142`) asume un solo manifiesto. Cambiarlo es delicado.
  - Probar en Taller: tests que verifiquen que un módulo de sistema escribe en el manifiesto de sistema y uno de usuario en el de usuario; y que `uninstall.sh` los fusiona.
  - Probar en Air: desinstalación real tras una instalación de fábrica.

### 3.5 Entrega (limpieza y licencia)

- **Nuevo `bin/second-wind-factory-deliver`**: comando/ botón "Preparar para entrega". Escribe la licencia
  OEM (llamando al empaquetador de licencia), siembra `/etc/skel` si hace falta, escribe
  `factory-deliver-pending`, habilita la unidad de limpieza y apaga.
- **Nuevo `/usr/local/sbin/second-wind-factory-reset`** + **unidad `second-wind-factory-reset.service`**
  (instalada por `install.sh --factory` o por el comando de entrega): la limpieza descrita en 2.c.
  - Riesgo (alto): tocar `/etc/machine-id`, `/etc/NetworkManager/system-connections` y borrar usuarios. Mitigación: el script debe ser explícito, idempotente, no usar comodines peligrosos (`rm -rf` con rutas fijas y verificadas), y llevar un log en `/var/log/`. Nunca borrar `/etc` completo ni `rm -rf $HOME` con variable vacía (usar `set -u`).
  - Probar en Taller: un test con `FAKE_ROOT` (variable de entorno que el script respeta) que simule `/etc` y `/home` en un `TMPDIR`, y verifique cada borrado y la escritura del marcador. Nada toca el sistema real.
  - Probar en Air: una corrida completa y después verificar que la máquina arranca al asistente del comprador.

### 3.6 Licencia OEM

- **Nuevo `bin/second-wind-oem-license`** (o extender `bin/second-wind-experience`):
  - Comando `verify`: lee `/etc/second-wind/license-oem`, verifica la firma con la llave pública del
    producto (`/usr/share/second-wind/oem-pub.pem`) y, si es válida, marca el Mac Experience activo.
  - (Para el taller de Second Wind) comando `sign`: firma un archivo de lote con la llave privada (que
    NUNCA viaja en el producto).
- **Modificar `bin/second-wind-experience`**: en `ensure_state` (`:36-49`) y en `day30_check` (`:195-229`),
  aceptar la licencia OEM de sistema como estado `active` y saltar el bloqueo de día 30. Añadir un subestado
  visible (`active (oem)`) para diagnóstico.
  - Riesgo: que una licencia OEM falsa (archivo escrito por el usuario) active el producto. Mitigación: exigir que el archivo sea propiedad de root y esté en `/etc/second-wind/`; verificar la firma; rechazar cualquier archivo en rutas escribibles por el usuario.
  - Probar en Taller: test que genere un par de llaves de prueba, firme una licencia, verifique aceptación, verifique rechazo con firma manipulada, y verifique que una clave Lemon normal NO pasa por el verificador OEM y viceversa (ver sección 4).
  - Probar en Air: activación real tras la entrega.

### 3.7 Semilla de usuario y `/etc/skel`

- **Revisar `usb/seed/user-data:227-247`**: hoy copia el autostart a cada home existente y a `/etc/skel`.
  En fábrica, cuando se corre la semilla, el único home es el del técnico; `/etc/skel` queda bien. Verificar
  que la entrega no borre `/etc/skel` (la limpieza solo toca homes de usuario, no `/etc/skel`).
  - Probar en Taller: test que inspeccione el árbol de la semilla generada.

### 3.8 Caché compartida (mejora de velocidad, opcional)

- Hoy las descargas van a `$SW_CACHE` dentro del home (`lib/common.sh:9`). Para que la Fase B sea rápida y
  funcione aun sin internet, mover la caché de descargas compartidas (temas, extensión, fuente, Íconos) a un
  directorio de sistema, por ejemplo `/var/cache/second-wind`, poblado en la Fase A.
  - Riesgo: cambio en varios módulos (20, 30). Es una optimización, no un requisito; se puede dejar para una
    segunda iteración.
  - Probar en Taller: test que verifique que los módulos usan la caché de sistema cuando existe.

### 3.9 Tests nuevos propuestos (todos en Taller)

- `tests/factory/test_install_split.sh`: cobertura y no solapamiento del particionado de módulos; parseo de `--factory`/`--user-only`.
- `tests/factory/test_factory_seed.sh`: la semilla de fábrica conserva las guardas P0 y no pregunta la identidad.
- `tests/factory/test_firstboot_phase.sh`: el firstboot elige fase según marcadores.
- `tests/factory/test_factory_reset.sh`: la limpieza, con `FAKE_ROOT`, borra lo esperado y nada más.
- `tests/factory/test_oem_license.sh`: firma, verificación, rechazo de manipulación, separación respecto de Lemon.

Todo lo anterior corre en el Taller. La VM QEMU permite además ensayar el flujo completo de las dos fases
sin Mac, porque las guardas aceptan `QEMU*` (`usb/seed/user-data:49`, `:88`, `:102`) y la documentación
deja constancia de que el flujo ya se validó en QEMU/OVMF (`docs/usb-installer.md:43-50`). Lo que la VM NO
prueba: WiFi Broadcom real, cámara, fan, teclado físico, y el modo usuario nuevo real de GNOME Initial
Setup con GDM.

---

## 4. Licencias por lote

Problema: las claves de fábrica deben activar el Mac Experience en los equipos que vende el
reacondicionador, pero NO deben poder usarse en la compra normal de US$10 (ni al revés).

### 4.1 Mecanismo recomendado: licencia firmada offline (Ed25519)

- Second Wind genera un par de llaves Ed25519. La **llave privada** queda offline, solo en poder de Second
  Wind (para firmar los lotes). La **llave pública** viaja dentro del producto
  (`/usr/share/second-wind/oem-pub.pem`).
- Por cada lote (una orden de compra, un contenedor de equipos, o una unidad si se quiere trazabilidad
  individual), Second Wind produce un archivo de licencia firmado:

  ```
  Second Wind OEM license v1
  batch=REUSE-2026-11
  issued=2026-10-01
  kind=oem
  sig=<base64 de la firma Ed25519 sobre las líneas anteriores>
  ```

- El aparato verifica la firma con la llave pública. Si es válida y `kind=oem`, activa el Mac Experience.
- Verificación sin servidor: `openssl pkeyutl -verify` (OpenSSL 3 está en Ubuntu 24.04) o
  `python3-cryptography`. No requiere internet ni servidor propio.
- La licencia se guarda en `/etc/second-wind/license-oem`, propiedad de root. El producto solo acepta el
  archivo desde esa ruta de sistema, nunca desde el home del usuario.

Por qué es la mejor opción:

1. **Funciona offline**, que es la condición real de la fábrica y de la mayoría de los compradores.
2. **No se puede falsificar** sin la llave privada.
3. **No colisiona con la compra normal**: el flujo normal (`bin/second-wind-experience:134-180`) es una
   clave de Lemon que se valida contra la API de Lemon; un archivo firmado no es una clave de Lemon y no
   tiene por dónde entrar. Y el verificador OEM exige `kind=oem` y firma válida, así que una clave Lemon
   tampoco activa por esa vía.
4. **Simple**: no hay servidor, ni base de datos, ni contador de activaciones.

Límites que hay que aceptar y documentar:

- **No hay revocación** offline. Una vez firmado un lote, no se puede invalidar.
- **No hay conteo de activaciones**. El mismo archivo sirve para cualquier cantidad de equipos.
- Si el archivo se filtra, sirve para activar cualquier máquina donde alguien con root lo copie. Es la
  misma clase de riesgo que una clave de Lemon filtrada. Se puede mitigar con (a) un `batch` que quede
  registrado en el libro de Second Wind, (b) una fecha de emisión, y (c) opcionalmente, más adelante, un
  chequeo en línea no obligatorio.
- No se puede atar al `machine-id` (el diseño lo regenera en la entrega, sección 2.c), así que la licencia
  es por lote y no por unidad.

### 4.2 Alternativa: producto B2B de Lemon con muchas activaciones

Se podría crear un producto separado en Lemon (por ejemplo "Mac Experience OEM") con un límite alto de
activaciones y entregar esa clave al reacondicionador. Ventaja: reutiliza la plomería que ya existe.
Desventajas para este caso:

- Necesita internet en la fábrica para activar (o pre-activar cada equipo).
- El chequeo actual valida solo `store_id` (`bin/second-wind-experience:156-166`), no el producto. Como el
  producto B2B sería de la misma tienda, una clave OEM filtrada pasaría por el **flujo normal** de cualquier
  comprador, con activaciones ilimitadas. Eso rompe justo la separación que se pide.
- Consume y administra un cupo de activaciones; menos simple de operar para lotes grandes.

### 4.3 Recomendación

Usar la **licencia firmada offline (Ed25519)** de 4.1. Es más simple, no depende de internet ni de un
tercero, y separa limpiamente la compra de US$10 de la licencia de fábrica. Guardar la llave privada con
cuidado (es el único activo crítico) y mantener un libro simple de lotes emitidos (batch, fecha, cliente).

---

## 5. Riesgos principales

1. **Estado de usuario borrado con el técnico**: casi toda la experiencia (temas, extensiones, Toshy,
   tienda, gsettings) vive en el home; al borrar el usuario técnico se pierde. La Fase B debe recrearla para
   el comprador, y hay que confirmar que puede quedar en menos de 2 minutos (Toshy es el bloque más pesado).
   Riesgo asociado: el manifiesto de cambios de sistema hoy vive en el home (se pierde), por eso se propone
   un manifiesto de sistema aparte.
2. **Modo "usuario nuevo" de GNOME Initial Setup no confirmado**: no se puede verificar desde el repositorio
   que GDM, con 0 usuarios, muestre el asistente con creación de cuenta en Ubuntu 24.04. A verificar en el
   Air; respaldo: el modo OEM de Ubuntu.
3. **Limpieza de rastros sin romper el equipo**: regenerar `machine-id`, borrar perfiles WiFi del taller,
   claves SSH de host y logs es sensible; un error afecta a todos los equipos del lote. Debe ser explícito,
   idempotente y probado con `FAKE_ROOT` antes de tocar un Mac. Añadir a esto que la licencia OEM no se puede
   revocar ni contar.

---

## 6. Estado de implementación (2026-10-01)

Esta sección es la bitácora de lo ya construido sobre este diseño. La Parte 1 (partición sistema/usuario) y
la Parte 2 (semilla de fábrica, entrega y licencia OEM) están implementadas y cubiertas por tests que corren
en el Taller, sin root y sin red. Lo que sigue pendiente es lo que solo se puede probar o completar en el
MacBook Air real.

### 6.1 Hecho

| Área | Archivos |
|---|---|
| Partición y fases (Parte 1) | `install.sh` (`--factory`/`--user-only`, `SW_PHASE`), `usb/firstboot/second-wind-firstboot.sh`, `lib/common.sh`, `lib/manifest.py` |
| Semilla de fábrica (3.1) | `scripts/make-usb.sh` (`--factory` y el transform `seed_factory_transform`) |
| Entrega (3.5) | `bin/second-wind-factory-deliver`, `factory/second-wind-factory-reset`, `factory/second-wind-factory-reset.service` |
| Licencia OEM (3.6, 4.1) | `scripts/oem-license.py`, `lib/oem_license.py`, `assets/oem-pub.pem`, `bin/second-wind-experience` |
| Tests | `tests/factory/test_factory_seed.sh`, `test_factory_reset.sh`, `test_factory_deliver.sh`, `test_oem_license.sh` |

La variante de fábrica de la semilla se genera aplicando un transform sobre `usb/seed/user-data`, no
duplicándolo. Así las guardas P0 (`early-commands`) y el `storage` se heredan intactos y no pueden
desincronizarse entre las dos semillas (un test lo verifica comparando los bloques).

### 6.2 Decisiones distintas del diseño original

1. **Formato de la licencia OEM: clave de una línea.** El diseño (4.1) propone un bloque multilínea con
   `batch`, `issued`, `kind` y `sig`. Se implementó una **clave corta de una línea**
   (`SWOEM1:<lote>:<numero>:<firma>`) porque el técnico la escribe a mano. El mensaje firmado (canónico) es
   el mismo concepto: `SWOEM1\nbatch=<lote>\nserial=<numero>\nkind=oem`. La firma sigue siendo Ed25519 vía
   OpenSSL, la verificación sigue siendo offline y la separación respecto de Lemon se mantiene.
2. **La limpieza no vuelve a apagar.** El diseño (2.c) acepta "se apaga sola" o "arranca directo al
   asistente". Se eligió lo segundo: el reset limpia y deja que GDM arranque con 0 usuarios para que GNOME
   Initial Setup cree la cuenta del comprador (un solo apagado, el de "Preparar para entrega").
3. **La unidad de limpieza la instala el comando de entrega**, no `install.sh --factory` (el diseño permitía
   ambas). Así la fase de fábrica queda con menos archivos de sistema y el comando de entrega la puede
   reinstalar de forma idempotente si hace falta.
4. **Ruta de la llave pública en ejecución:** `assets/oem-pub.pem` dentro del payload (bajo `SW_ROOT`), no
   `/usr/share/second-wind/oem-pub.pem`, para no introducir otra ruta de instalación.
5. **El placeholder de la llave pública no es una llave válida**: cualquier licencia falla la verificación
   hasta que se genere el par real y se copie la mitad pública a `assets/oem-pub.pem`.
6. **`oem_active` re-verifica en cada corrida.** Un estado `oem` guardado en el home se revalida contra el
   archivo de licencia; si la licencia desaparece o se rompe, el equipo vuelve a `trial` en lugar de quedar
   abierto.

### 6.3 Qué falta en el Creator (macOS, Swift)

No se tocó `creator/macos`. Para que el reacondicionador genera el pendrive de fábrica desde la app gráfica,
el Creator todavía necesita:

- **Un modo "fábrica" en la interfaz** (un interruptor o una segunda acción "Crear USB de fábrica") que
  elija la variante de semilla de fábrica en lugar de la normal.
- **Aplicar el mismo transform de semilla que hace `scripts/make-usb.sh --factory`** (o empaquetar el
  `user-data` de fábrica ya transformado) dentro del motor que arma el volumen `CIDATA`. Hoy el Creator
  arma la semilla por su cuenta en Swift, así que hay que replicar allí la transformación, o mover el
  transform a un punto común que el Creator pueda invocar.
- **Una revisión de textos**: la app hoy describe las 4 pantallas del comprador (idioma, teclado, WiFi,
  nombre/contraseña); en modo fábrica solo se piden idioma, teclado y WiFi.
- **La clave OEM** no la maneja el Creator: se ingresa en la máquina con
  `second-wind-factory-deliver license <CLAVE-OEM>` después de instalar.

### 6.4 Qué queda por probar solo en el MacBook Air real

- Arranque real del pendrive de fábrica y que la instalación no pida la identidad del comprador.
- Que GDM, con la máquina sin usuarios tras la limpieza, muestre GNOME Initial Setup con la página de
  creación de cuenta, y que `/etc/skel` (con el autostart de Second Wind) se copie a esa cuenta nueva.
- Que el orden `Before=display-manager.service` de la unidad de limpieza se respete y que la limpieza
  borre de verdad el usuario técnico, los WiFi del taller y el `machine-id`.
- Que el reloj del `machine-id` regenerado no rompa la licencia OEM (no debería: la licencia no se ata al
  `machine-id`).
- Que la activación OEM por `/etc/second-wind/license-oem` quede activa para el comprador sin oferta de
  compra ni llamada a Lemon.
- La corrida real de `install.sh --factory` y `--user-only` (duración y el bloque de Toshy).
