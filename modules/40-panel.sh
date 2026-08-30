#!/usr/bin/env bash
# 40-panel — barra superior y comportamiento de ventanas al estilo macOS.

# Esquina activa (arriba-izquierda = vista general, como Mission Control)
gset_track org.gnome.desktop.interface enable-hot-corners true
# Botones de ventana a la izquierda: cerrar, minimizar, maximizar
gset_track org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:'"
# Reloj con día de la semana, como la barra de menús de macOS
gset_track org.gnome.desktop.interface clock-show-weekday true
# Ventanas nuevas centradas
gset_track org.gnome.mutter center-new-windows true
# Batería: activar automáticamente el modo de ahorro cuando quede poca,
# como hace macOS (el resto de la gestión la llevan power-profiles-daemon,
# thermald y mbpfan — TLP se descarta a propósito: rompe el selector de
# energía de GNOME)
gset_track org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery true
# Nota: overlay-key se deja vacía a propósito (pulsar Cmd solo no abre nada,
# igual que en un Mac); la vista general queda en la esquina activa y el gesto
# de 3 dedos hacia arriba.
