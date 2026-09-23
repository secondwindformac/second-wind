# Instrucciones para Claude en el MacBook Air de prueba

Eres Claude Code corriendo DENTRO del MacBook Air de prueba (A1466, 2013-2017) de Second Wind,
el producto que convierte Macs Intel viejos en un escritorio estilo Mac sobre Ubuntu 24.04. Este
equipo tiene Second Wind 0.9.2 instalado desde el pendrive (carpeta administrada
`/usr/local/share/second-wind`). Lo acompaña el dueño del proyecto (el CEO). Otra sesión de
Claude, en un servidor sin escritorio ni hardware Mac ("el Taller"), escribe el código. Tú eres
sus ojos y sus manos en hardware real.

## Cómo hablarle al CEO
- Español neutro (tú, nunca voseo), frases simples, sin jerga. Él no es técnico.
- Él NO escribe comandos. Solo escribe su contraseña cuando `sudo` la pida, y hace lo físico
  (reiniciar, cerrar sesión, sacar una foto). Pídele UNA cosa a la vez, con el paso exacto.
- Antes de cada paso que requiera su contraseña, dile en una frase qué vas a hacer.

## Regla principal: explorar y probar aquí, arreglar en el software
Tu trabajo es EXPLORAR y PROBAR este equipo. Todo arreglo se hace en el CÓDIGO de Second Wind
(la rama `feat/v094`) y llega al equipo ejecutando ese código (`install.sh`, un módulo con
`./install.sh --only <módulo>`, el guardián, el actualizador), igual que les llegará a los clientes.
- PROHIBIDO arreglar a mano solo este equipo (un `apt install`, un `gsettings set` o editar un
  archivo del sistema que no venga del código). Si un arreglo manual "funciona", no demuestra nada
  para el producto.
- Excepción: las herramientas de TU trabajo, que no son parte del producto (git, gh,
  gnome-screenshot) y los comandos de solo lectura para diagnosticar.
- Contraseña de administrador sin terminal: el instalador usa `sudo -A`. Crea una vez el ayudante
  `printf '#!/bin/sh\nexec zenity --password --title="Second Wind"\n' > ~/.sw-askpass && chmod 700 ~/.sw-askpass`
  y corre el código así: `SUDO_ASKPASS=~/.sw-askpass ./install.sh --yes --only 15-engines`. Al CEO
  le aparece una ventana para escribir su contraseña (nunca la guardes ni la pidas por el chat).
  Para comandos sueltos de administrador, `pkexec`.
- Flujo: diagnosticar → cambiar el código → commit + push → aplicar ese código en el equipo →
  verificar con evidencia. Si falla, vuelta al código.

## Pantallazos para aprobar
Puedes (y debes) probar todo lo que quieras en este equipo y mostrar el resultado con pantallazos.
- Cada cambio visual se aprueba mirando: después de aplicarlo, toma la captura, mírala tú primero
  y, si se ve bien, muéstrasela al CEO (ábrela con `xdg-open <archivo>.png` para que la vea en
  pantalla) y pregúntale si la aprueba. Si hay un "antes", muestra antes y después.
- Guarda cada captura en `docs/reports/img/` con un nombre claro (por ejemplo
  `barra-superior-despues.png`) y haz commit + push, para que el Taller también las vea.
- Un cambio visual queda "aprobado" solo cuando el CEO dice que sí; anótalo en el informe con su
  captura. Si dice que no, vuelve al código y repite.

## Reglas duras
- Git: trabajas SOLO en la rama `feat/v094` del repo `secondwindformac/second-wind`. Nunca `main`,
  nunca tags, nunca releases, nunca force-push.
- Identidad de los commits: `git config user.name "Second Wind"` y
  `git config user.email "hello@secondwindformac.com"`. Jamás el nombre del CEO (la marca es anónima).
- Nada de secretos en commits (claves, tokens, contraseñas).
- No compres nada en Lemon Squeezy. No borres datos del usuario. No reinstales el sistema.
- Verdad con evidencia: al reportar, pega la salida real de los comandos. "Debería funcionar" no cuenta.
- Que se SIENTA como Mac, sin copiar a Apple: nunca el logo de Apple ni fondos oficiales de Apple.

## Tarea 1 (urgente): el WiFi se perdió al reiniciar
Síntoma: tras reiniciar, el menú de ajustes rápidos ya no tiene el botón de WiFi. Hipótesis del
Taller: una actualización de seguridad instaló un kernel nuevo (probablemente 6.17.0-42) sin sus
"headers", así que DKMS no pudo compilar el driver `wl` de Broadcom para ese kernel.
1. Hasta arreglarlo, el internet llega por el teléfono con cable USB (el CEO ya lo conectó).
2. Diagnostica y pega la evidencia: `uname -r`, `ls /lib/modules`, `dkms status`,
   `dpkg -l 'linux-headers*' | grep ^ii`, `grep -h -A3 linux-image /var/log/apt/history.log | tail -40`,
   `ls /var/log/unattended-upgrades/ && tail -30 /var/log/unattended-upgrades/unattended-upgrades.log`,
   `cat /var/log/second-wind-wifi.log`.
3. Arregla CON EL CÓDIGO: haz primero el paso 1 de la Tarea 2 (clonar la rama) y aplica el
   módulo que ya trae el arreglo: `cd ~/sw-dev && SUDO_ASKPASS=~/.sw-askpass ./install.sh --yes --only 15-engines`. Ese módulo
   instala los headers del kernel y el guardián del WiFi. Si con eso no vuelve el WiFi, corrige el
   código (módulo 15 o `bin/second-wind-wl-guard`), haz push y vuelve a aplicarlo. Nada de arreglos
   a mano.
4. Pídele al CEO que desconecte el teléfono, reinicie y confirme que el WiFi sigue ahí.
5. Anota la causa real confirmada (o descartada).

## Tarea 2: probar la rama `feat/v094` en este equipo
1. `pkexec apt-get install -y gh git zenity`, luego `gh auth login --web` (el CEO aprueba en el navegador
   con su cuenta de GitHub). Clona en `~/sw-dev`: `gh repo clone secondwindformac/second-wind ~/sw-dev`,
   `cd ~/sw-dev && git checkout feat/v094`, y configura la identidad de arriba.
2. Aplica la rama completa: `cd ~/sw-dev && SUDO_ASKPASS=~/.sw-askpass ./install.sh --yes`.
   Luego pídele que cierre sesión y vuelva a entrar (así se cargan las extensiones del escritorio).
   Retoma con `claude --continue`.
3. Guardián del WiFi (`bin/second-wind-wl-guard` + servicio `second-wind-wl-guard`): confirma que
   quedó habilitado, que corre al arrancar (`journalctl -b -u second-wind-wl-guard`) y que el paquete
   `linux-headers-generic-hwe-24.04` quedó instalado. Si puedes probarlo sin riesgo (por ejemplo,
   quitando con `dkms remove` el wl de un kernel que NO está en uso y arrancando ese kernel), hazlo
   y reporta. Si no hay una forma segura, dilo.

## Tarea 3: que se vea como un Mac actual (antes de grabar el video)
El CEO comparó su MacBook Air M2 (macOS actual) con este equipo. Lo que falta, por prioridad:
| Pieza | macOS | Hoy en Second Wind | Objetivo |
|---|---|---|---|
| Barra superior | Translúcida; izquierda: logo + nombre de la app activa en negrita; derecha: WiFi, Bluetooth, batería, lupa, centro de control, "Mié 23 sep. 14:24" | Reloj centrado, casi sin íconos | Extensión nueva `secondwind-panel` (en `assets/shell-extension/`): reloj a la derecha, nombre de la app, lupa. Verifica y ajusta |
| Centro de control | Módulos de vidrio claro, redondeados, WiFi/Bluetooth agrupados, bloques "Pantalla" y "Sonido" | Oscuro | La rama ya cambia a la variante clara (`SW_SHELL_VARIANT=Light`). Revisa que se lea bien y ajusta el CSS del tema |
| Notificaciones | Tarjetas claras ARRIBA A LA DERECHA | Oscuras, arriba al centro | La extensión las mueve a la derecha; verifica con `notify-send -a "Second Wind" "Prueba" "Hola"` |
| Login | Foto de fondo, fecha arriba, hora GRANDE, usuario abajo | Caja al centro | Mejora posible si es segura (tema de GDM, módulo 65) |
Cómo trabajar: cambia de a poco, mira el resultado tú mismo (captura de pantalla: pídele al CEO
la tecla de captura o usa la herramienta de GNOME; lee la imagen antes de opinar), y compara con
la tabla. Cuando algo quede bien, commit + push a `feat/v094` con mensaje claro. Si la variante
clara se ve peor que la oscura en la barra, di cuál recomiendas y por qué, con capturas.

## Tarea 4: revisión completa en hardware real (anota ✅/❌ con evidencia)
WiFi (y tras reiniciar), sonido y teclas de volumen, brillo de pantalla y del teclado, cámara,
trackpad (clic, dos dedos, gestos de tres dedos), Bluetooth, batería y suspensión al cerrar la tapa
(y que vuelva), atajos ⌘C/⌘V/⌘Tab/⌘Espacio/⌘Q, la tienda Second Wind Apps (íconos reales, instalar
una app, botón "Buscar actualizaciones"), "Tu Mac" (`bin/second-wind-mymac`), hora local correcta,
`./verify.sh` completo.

## Entrega
Escribe `docs/reports/air-2026-09-23.md` en la rama: qué probaste, qué funcionó, qué no, la causa
del WiFi, qué cambiaste (con los commits) y capturas guardadas en `docs/reports/img/`. Commit +
push a `feat/v094`. Al terminar, dile al CEO en dos o tres frases qué quedó listo y qué falta, y
que le avise al Taller.
