# Second Wind

**Un segundo aire para tu Mac antiguo.** Second Wind convierte un Mac Intel de 2013-2017 que Apple dejó de actualizar en un computador rápido y seguro que se sigue viendo y sintiendo como un Mac. Armas un pendrive con nuestra app, enciendes el Mac desde él, respondes cuatro preguntas y el resto lo hace solo. Sin terminal y sin saber de Linux.

🌐 **[secondwindformac.com](https://secondwindformac.com/es/)**: descarga, videos, "¿Sirve mi Mac?" y preguntas frecuentes.

![El mismo Mac después de Second Wind](https://secondwindformac.com/assets/after.png)

*Read in English: [README.md](README.md)*

## En corto

- **Qué es:** Ubuntu 24.04 LTS (un sistema operativo gratuito y legal, con actualizaciones de seguridad hasta 2029), configurado y vestido para verse y comportarse como un Mac, con los drivers que necesitan los MacBook antiguos.
- **Para quién:** personas con un Mac Intel de 2013-2017 que ya no recibe actualizaciones de macOS y que quieren volver a usarlo para internet, videollamadas, estudiar, trabajar, música y videos.
- **Precio:** Second Wind es **gratis para siempre**: el look completo de Mac, los drivers, la tienda de apps y las actualizaciones. **Mac Experience** son solo los atajos de teclado ⌘ y la búsqueda ⌘Espacio: 30 días gratis y después **US$10 una sola vez** (no es una suscripción). Sin Mac Experience tu Mac se sigue viendo como un Mac; solo los atajos ⌘ vuelven a los de Linux.
- **Qué no es:** no es macOS y no contiene software, logos ni fuentes de Apple. Usa un tema libre de la comunidad, el símbolo ⌘ y la fuente libre Inter. No tiene iMessage, FaceTime, AirDrop ni apps exclusivas de Mac (.dmg). Si necesitas macOS de verdad, mira "Cómo se compara" más abajo.

## Qué recibes

- **El look de Mac:** dock abajo, barra superior con menú ⌘, hora e íconos de estado a la derecha, centro de control claro, botones rojo, amarillo y verde en las ventanas, fondo de pantalla dinámico.
- **El teclado de Mac (Mac Experience):** ⌘C, ⌘V, ⌘Z, ⌘Q, ⌘Tab, búsqueda ⌘Espacio, ⌘⇧3/4/5 para capturas y grabar la pantalla.
- **Hardware que simplemente funciona:** Wi-Fi (Broadcom, funcionando desde el primer encendido, incluso sin internet durante la instalación), cámara FaceTime HD, sonido, ventilador, reposo e hibernación, teclas de función.
- **Una tienda con 22 apps:** Chrome, WhatsApp, Zoom, Spotify, oficina y más, un clic cada una, siempre desde fuentes oficiales.
- **"Tu Mac":** revisa tu equipo y tiene el botón "Copiar informe para soporte" (una lista cerrada de datos que ves completa antes de copiarla; no se envía nada).
- **Actualizaciones automáticas**, que vuelven atrás solas si algo empeora.

## ¿Sirve mi Mac?

| Mac | Años | Estado |
|---|---|---|
| MacBook Air 11" / 13" | 2013-2017 | Listo (probado de punta a punta en un MacBook Air A1466) |
| MacBook Pro Retina 13" / 15" | 2013-2015 | Listo (beta: cuéntanos cómo te va) |
| iMac 21,5" / 27" | 2013-2015 | Listo (beta: cuéntanos cómo te va) |
| MacBook Pro 13" / 15" (era Touch Bar) | 2016-2017 | En desarrollo |
| Macs con chip Apple T2 | 2018 en adelante | Todavía no (el instalador se detiene antes de borrar nada) |
| Apple Silicon (M1 en adelante) | 2020 en adelante | Sin planes (Apple todavía los actualiza) |

Lista exacta por número de modelo (el "A1466" que aparece bajo el Mac): [secondwindformac.com/es/compatibilidad](https://secondwindformac.com/es/compatibilidad/).

## Cómo se instala

1. **Arma el pendrive** (de 8 GB o más) con **Second Wind Creator** en cualquier Mac (o con la app para Ubuntu en un PC con Linux). Descarga la imagen oficial de Ubuntu y Second Wind, y verifica cada pieza contra su huella oficial.
2. **Enciende el Mac antiguo desde el pendrive:** mantén la tecla **Option (⌥)** mientras enciende y elige el disco amarillo "EFI Boot".
3. **Responde cuatro preguntas** (idioma, teclado, Wi-Fi, tu nombre). La primera vez que entras, Second Wind termina de dejar todo listo por sí solo (unos 15 minutos, con barra de progreso).

Importante: **Second Wind reemplaza macOS por completo y borra el Mac.** Respalda tus archivos antes. Siempre puedes volver a macOS con la recuperación por internet que trae el Mac: [guía de rescate](https://secondwindformac.com/es/rescue/).

## Cómo se compara

| Si quieres... | La mejor opción |
|---|---|
| Un computador rápido, seguro y con sensación de Mac para el día a día, sin terminal | **Second Wind** |
| macOS de verdad en un Mac sin soporte, con apps de Apple e iMessage | **OpenCore Legacy Patcher** (gratis; técnico; macOS 26 es la última versión de Apple para Macs Intel, así que su futuro es incierto) |
| Un computador solo para el navegador (cuenta de Google, apps web) | **ChromeOS Flex** (gratis; algunos Macs están en la lista certificada de Google) |
| Un Linux de uso general con apariencia personalizable | **Zorin OS** o **Ubuntu** normal (los drivers de Mac y los atajos de Mac corren por tu cuenta) |

Más detalle: [secondwindformac.com/es/comparar](https://secondwindformac.com/es/comparar/).

## Privacidad

Second Wind no envía datos tuyos. Solo consulta si hay mejoras, baja los íconos de la tienda y activa tu licencia cuando tú lo pides. Sin cuentas y sin publicidad.

## Ayuda

Escribe a **hello@secondwindformac.com**. En "Tu Mac", el botón "Copiar informe para soporte" nos da lo necesario para ayudarte rápido.

## Licencia

Todo el código está a la vista y es auditable, y es gratis para siempre para tu Mac. Puedes leerlo, auditarlo, cambiarlo y usarlo, en casa o en el trabajo. Lo único que la licencia prohíbe es tomar este código para ofrecer un producto que compita. Es **código a la vista bajo [PolyForm Shield 1.0.0](LICENSE)**, no una licencia "open source" de la OSI (ver [NOTICE](NOTICE)).

Los componentes de terceros (tema, extensiones, drivers) no se redistribuyen: el instalador los descarga de sus fuentes oficiales en versiones verificadas, bajo sus propias licencias ([THIRD_PARTY.md](THIRD_PARTY.md)). Las contribuciones se aceptan según [CONTRIBUTING.md](CONTRIBUTING.md).

Second Wind es un proyecto independiente, sin afiliación, respaldo ni patrocinio de Apple Inc. ni de Canonical Ltd. "Mac", "macOS" y "MacBook" son marcas de Apple Inc., mencionadas solo para describir compatibilidad. "Ubuntu" es una marca de Canonical Ltd.

---

## Para desarrolladores

Las personas nunca necesitan esta sección: el pendrive hace todo. Está aquí para quien quiera leer, auditar o mejorar el código.

- **Base:** Ubuntu 24.04 LTS, GNOME 46, Wayland. Cada pieza externa está fijada a versiones probadas juntas (`versions.lock`).
- **Instalador USB:** ISO oficial de Ubuntu + semilla de instalación automática + Second Wind; ver [docs/usb-installer.md](docs/usb-installer.md). Apps creadoras: [creator/macos](creator/macos/) y `apps/usb-creator.py`.
- **Aplicar la capa sobre un Ubuntu 24.04 ya instalado:**

```bash
git clone https://github.com/secondwindformac/second-wind.git
cd second-wind
./install.sh            # --dry-run, --yes, --no-hardware, --only <módulo>
./verify.sh             # revisión de salud
./uninstall.sh          # deja Ubuntu como estaba, con el respaldo tomado al inicio
```

- Los módulos están en `modules/`, el actualizador en `bin/second-wind-update` y la app en `apps/second-wind-apps.py`. Hoja de ruta y notas honestas de factibilidad: [docs/roadmap.md](docs/roadmap.md).
