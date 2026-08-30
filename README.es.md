# Second Wind

**Un segundo aire para tu Mac vieja — convierte Ubuntu en una experiencia tipo macOS en un solo paso, sin saber de Linux.**

*Read in English: [README.md](README.md)*

Apple dejó sin actualizaciones a millones de Macs Intel perfectamente capaces. Con Ubuntu siguen siendo computadores excelentes, pero se sienten ajenos. Second Wind los hace sentirse como en casa:

- 🖥️ **Apariencia macOS completa**: tema de ventanas, iconos, cursor, fuentes y fondo dinámico día/noche (basado en el look de macOS Tahoe).
- 🚀 **Dock flotante**, barra superior estilo Mac, botones de ventana a la izquierda y menú ⌘ arriba a la izquierda.
- 🔍 **Spotlight**: pulsa `Cmd + Espacio` y busca aplicaciones y archivos.
- ⌨️ **Teclado de Mac de verdad**: `Cmd+C` copia, `Cmd+V` pega, `Cmd+Q` cierra, `Cmd+Tab` cambia entre apps de todos los escritorios — y en la Terminal `Cmd+C` copia sin matar el programa, como en macOS.
- 🔧 **Arreglos de hardware para MacBooks**: cámara FaceTime HD, ventilador inteligente y teclas F persistentes.
- ↩️ **Todo reversible**: respaldo completo antes de tocar nada; `./uninstall.sh` deja Ubuntu como estaba.

El instalador habla **español e inglés** (sigue el idioma de tu sistema).

## Requisitos

- Ubuntu **24.04 LTS** con escritorio GNOME 46 (la instalación estándar), sesión Wayland (la por defecto).
- Internet y 2 GB libres.
- Pensado y probado en MacBooks Intel (equipo de referencia: MacBook Air 13" 2014). También funciona en PCs normales con Ubuntu 24.04 (el módulo de hardware Mac se omite solo).

### ¿Por qué exactamente Ubuntu 24.04 + GNOME 46?

Cada pieza externa (tema, cuatro extensiones GNOME, driver de cámara) está **fijada a versiones probadas juntas** en el equipo de referencia (`versions.lock`). Otra versión de GNOME necesita otros pines: soportar una versión significa re-probar la experiencia completa. El plan: seguir las versiones **LTS** de Ubuntu (24.04 ahora, 26.04 después), y que el USB de instalación de la Etapa 2 traiga la base exacta ya probada, para que el usuario final nunca piense en versiones.

## Instalar

```bash
git clone https://github.com/USER/second-wind.git
cd second-wind
./install.sh
```

Opciones útiles: `--dry-run` (muestra sin cambiar), `--yes` (sin preguntas), `--no-hardware`, `--only dock`, `./verify.sh`, `./uninstall.sh`. Los alias en español (`--si`, `--solo`, `--verificar`, `--desinstalar`) también funcionan.

Preguntas frecuentes y limitaciones honestas: ver [README.md](README.md) (inglés) o [docs/es/](docs/es/).

## Licencia

Código propio bajo licencia [MIT](LICENSE). Los componentes de terceros no se redistribuyen: se descargan de sus fuentes oficiales en versiones verificadas ([THIRD_PARTY.md](THIRD_PARTY.md)).

Second Wind no está afiliado a Apple Inc. "Mac" y "macOS" son marcas de Apple Inc.; se mencionan solo para describir compatibilidad y semejanza visual.
