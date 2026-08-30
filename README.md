# MacConLinux

**Convierte tu Mac viejo con Ubuntu en una experiencia tipo macOS, en un solo paso y sin saber de Linux.**

Apple dejó sin actualizaciones a millones de Macs Intel perfectamente capaces. Con Ubuntu siguen siendo computadores excelentes, pero se sienten "ajenos". MacConLinux los hace sentirse como en casa:

- 🖥️ **Apariencia macOS completa**: tema de ventanas, iconos, cursor, fuentes y fondo de pantalla dinámico día/noche (basado en el look de macOS Tahoe).
- 🚀 **Dock flotante** y barra superior al estilo Mac, con botones de ventana a la izquierda.
- 🔍 **Spotlight**: pulsa `Cmd + Espacio` y busca aplicaciones y archivos.
- ⌨️ **Teclado de Mac de verdad**: `Cmd+C` copia, `Cmd+V` pega, `Cmd+Q` cierra, `Cmd+Tab` cambia de aplicación — y en la Terminal `Cmd+C` copia sin cortar el programa, como en macOS.
- 🔧 **Arreglos de hardware para MacBooks**: cámara FaceTime HD, control inteligente del ventilador y teclas F persistentes.
- ↩️ **Todo reversible**: antes de tocar nada se guarda un respaldo completo; `./uninstall.sh` deja Ubuntu como estaba.

## Requisitos

- Ubuntu **24.04 LTS** con escritorio GNOME 46 (la instalación estándar), sesión Wayland (la que viene por defecto).
- Conexión a internet y 2 GB libres.
- Pensado y probado en MacBooks Intel (equipo de referencia: MacBook Air 13" 2014). Funciona también en PCs normales con Ubuntu 24.04 (el módulo de hardware Mac simplemente se omite).

## Instalación

```bash
git clone https://github.com/USUARIO/MacConLinux.git
cd MacConLinux
./install.sh
```

El instalador explica lo que va a hacer, pide **una sola confirmación**, guarda el respaldo y aplica todo. Al final te pedirá cerrar sesión y volver a entrar (necesario para el tema del panel y el teclado por aplicación). La contraseña de administrador solo se pide para los arreglos de hardware.

Opciones útiles:

| Comando | Qué hace |
|---|---|
| `./install.sh --dry-run` | Muestra qué haría, sin cambiar nada |
| `./install.sh --si` | Instala sin preguntas (valores por defecto) |
| `./install.sh --sin-hardware` | Omite el módulo que pide contraseña |
| `./install.sh --solo dock` | Re-ejecuta un solo módulo |
| `./verify.sh` | Comprueba que todo esté en orden |
| `./uninstall.sh` | Restaura Ubuntu como estaba |

## Preguntas frecuentes

**¿Esto toca mis archivos?** No. Solo configura la apariencia y el comportamiento del escritorio. Tus documentos, fotos y programas no se tocan.

**¿Puedo volver atrás?** Sí, siempre: `./uninstall.sh` restaura cada ajuste a su valor original usando el respaldo que se guardó antes de empezar.

**Algunas apps no tienen los botones rojo/amarillo/verde.** Las aplicaciones que dibujan su propia ventana (Chrome, y las hechas con Electron, como muchas apps de escritorio modernas) no usan los botones del sistema. Para Chrome, MacConLinux activa su opción de "barra de título del sistema" y queda con botones Mac; en las apps Electron depende de cada aplicación y no se puede forzar.

**Los menús del sistema no son idénticos a los de macOS.** El panel y sus menús son de GNOME: MacConLinux los viste (colores, formas, tipografía, variante opaca legible), pero su estructura interna es la de Ubuntu.

**El App Center de Ubuntu se ve distinto.** Esa tienda no usa la tecnología de temas del sistema (GTK) y no se puede vestir.

**Firefox u otras apps de Snap no toman el tema.** Limitación conocida de los Snaps de Ubuntu; se aborda en la Etapa 1.

**¿Y la batería?** MacConLinux usa la gestión de energía propia de Ubuntu (perfiles de energía + `thermald`) y añade `mbpfan` para que el ventilador responda de verdad en MacBooks, más el ahorro automático al quedar poca batería. Se descartó TLP a propósito: choca con el selector de energía de GNOME. El mayor consumo suele venir de las aplicaciones abiertas, no del sistema.

**La cámara no se activó.** El driver de la cámara FaceTime HD es de terceros y se compila para tu kernel; si falla, el instalador lo revierte solo y lo deja documentado en `docs/camara.md`. Puedes reintentar tras una actualización con `./install.sh --solo hardware`.

**Ubuntu me pide "desbloquear el llavero" al entrar.** Pasa cuando el equipo entra sin contraseña (autologin). El instalador ofrece arreglarlo; detalles en `docs/llavero-autologin.md`.

## Estado del proyecto

**Etapa 0** (esta): instalador one-click para Ubuntu 24.04/GNOME 46, probado en el equipo de referencia.
**Etapa 1**: apps estilo Mac, modo oscuro conmutable, tema de la pantalla de acceso, inglés, GUI.
**Etapa 2**: pendrive de instalación total — de un Mac con macOS a un "Mac nuevo" con Ubuntu + MacConLinux, sin terminal.

## Licencia

Código propio bajo licencia [MIT](LICENSE). Los componentes de terceros (temas, extensiones, drivers) **no se redistribuyen**: el instalador los descarga de sus fuentes oficiales en versiones verificadas; ver [THIRD_PARTY.md](THIRD_PARTY.md).

MacConLinux no está afiliado a Apple Inc. "Mac" y "macOS" son marcas de Apple Inc.; se mencionan solo para describir compatibilidad y semejanza visual.
