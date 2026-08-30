#!/usr/bin/env bash
# 35-dock — deja el dock de Ubuntu con el aspecto del Dock de macOS:
# abajo (ya), flotante (no de borde a borde), iconos 48 px, sin discos montados.
# Se reutiliza el Ubuntu Dock (mismo motor que Dash to Dock): menos piezas, mismo look.

if [ "${HAVE_DOCK:-0}" != 1 ]; then
  warn "Este sistema no tiene el dock de Ubuntu; se omite (se configurará en una versión futura)."
  return 0
fi

gset_track org.gnome.shell.extensions.dash-to-dock extend-height false
gset_track org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48
gset_track org.gnome.shell.extensions.dash-to-dock show-mounts false
# El resto ya viene bien en Ubuntu: posición abajo, autoocultar, indicadores
# de punto y clic estilo macOS quedaron configurados en la auditoría previa.
