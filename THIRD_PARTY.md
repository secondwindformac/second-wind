# Componentes de terceros

MacConLinux (licencia MIT) **no incluye ni redistribuye** estos componentes: el
instalador los descarga de sus fuentes oficiales, en las versiones exactas
fijadas en `versions.lock`, y quedan instalados en el equipo del usuario bajo
sus propias licencias.

| Componente | Uso | Licencia | Fuente |
|---|---|---|---|
| MacTahoe GTK theme (vinceliuice) | Tema de ventanas y panel | GPL-3.0 | https://github.com/vinceliuice/MacTahoe-gtk-theme |
| MacTahoe icon theme + cursores (vinceliuice) | Iconos y cursor | GPL-3.0 | https://github.com/vinceliuice/MacTahoe-icon-theme |
| Inter (rsms) | Fuente del sistema | SIL OFL 1.1 | https://github.com/rsms/inter |
| User Themes (GNOME) | Activar el tema del panel | GPL-2.0+ | https://extensions.gnome.org/extension/19/user-themes/ |
| Blur my Shell (aunetx) | Transparencias del panel | GPL-3.0 | https://extensions.gnome.org/extension/3193/blur-my-shell/ |
| Xremap (k0kubun) | Detección de app activa (teclado por aplicación) | MIT | https://extensions.gnome.org/extension/5060/xremap/ |
| facetimehd + facetimehd-firmware (patjak) | Driver de la cámara FaceTime HD | GPL-2.0 (driver) | https://github.com/patjak/facetimehd |
| mbpfan (linux-on-mac) | Control del ventilador | GPL-3.0 | paquete `mbpfan` de Ubuntu |
| Toshy (RedBearAK) | Teclado estilo Mac por aplicación | GPL-3.0 | https://github.com/RedBearAK/toshy — MacConLinux lo configura si está presente; su instalación se integrará en la Etapa 1 |
| Ulauncher | Buscador (Spotlight) | GPL-3.0 | https://ulauncher.io — ídem |

Notas:

- El **firmware de la cámara** pertenece a Apple; el instalador lo extrae
  localmente de un paquete oficial de Apple en el equipo del usuario
  (herramienta `facetimehd-firmware`) y **nunca** se redistribuye.
- El tema CSS de Spotlight para Ulauncher (`assets/ulauncher/user-themes/`)
  es código propio de MacConLinux (MIT); hereda estilos del tema "light" de
  Ulauncher por referencia (`@import` a la ruta local), sin copiar su código.
