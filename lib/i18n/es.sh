#!/usr/bin/env bash
# Textos del instalador en español. Etapa 1 añadirá en.sh con las mismas claves.

declare -A MSG=(
  [bienvenida]="Bienvenido a MacConLinux

Este programa convertirá tu Ubuntu en una experiencia tipo macOS:

  • Apariencia completa estilo macOS (tema, iconos, cursor, fuentes, fondo)
  • Dock flotante y barra superior al estilo Mac
  • Botones de ventana a la izquierda y esquina activa
  • Buscador tipo Spotlight con Cmd+Espacio
  • Teclado con atajos de Mac (Cmd+C, Cmd+V, Cmd+Q…)
  • Arreglos para MacBooks: cámara, ventilador y teclas F

Antes de tocar nada se guarda un RESPALDO COMPLETO de tu configuración.
Todo se puede revertir después con ./uninstall.sh"

  [confirmar]="¿Comenzamos? Se hará primero el respaldo y luego se aplicarán los cambios. Solo tendrás que confirmar una vez."
  [cancelado]="Instalación cancelada. No se cambió nada."
  [preg_hardware]="¿Incluir los arreglos de hardware para MacBook (cámara FaceTime HD, ventilador, teclas F)?

Es el único paso que pedirá tu contraseña de administrador."
  [no_root]="No ejecutes este programa como root/sudo. Ábrelo con tu usuario normal; la contraseña se pedirá solo cuando haga falta."
  [modo_prueba]="MODO PRUEBA (--dry-run): no se cambiará nada; solo se muestra lo que se haría."

  [mod_20]="Apariencia macOS (tema, iconos, cursor, fuentes, fondo)"
  [mod_30]="Extensiones del escritorio (tema del panel, transparencias, teclado)"
  [mod_35]="Dock estilo macOS"
  [mod_40]="Barra superior y comportamiento de ventanas"
  [mod_45]="Teclado estilo Mac"
  [mod_50]="Spotlight (buscador con Cmd+Espacio)"
  [mod_60]="Hardware de MacBook (cámara, ventilador, teclas F)"
  [mod_70]="Aplicaciones estilo Mac"
  [mod_90]="Verificación tras el próximo inicio de sesión"

  [fin_ok]="¡Listo! La instalación terminó correctamente."
  [fin_avisos]="La instalación terminó, con algunos pasos omitidos (revisa los avisos ⚠ de arriba; nada crítico)."
  [preg_logout]="Para completar el cambio (tema del panel, dock y teclado por aplicación) hay que CERRAR SESIÓN y volver a entrar.

¿Cerrar sesión ahora? (Guarda antes tu trabajo abierto)"
  [logout_manual]="Cuando puedas, cierra sesión y vuelve a entrar para completar el cambio (menú de arriba a la derecha → Cerrar sesión)."
  [preg_autologin]="Tu equipo entra sin pedir contraseña (inicio de sesión automático), y por eso Ubuntu pide a veces desbloquear el 'llavero'.

¿Desactivar el inicio de sesión automático para arreglarlo? (Tendrás que escribir tu contraseña al encender, como en un Mac)"

  [des_confirmar]="Se restaurará la apariencia y configuración original de Ubuntu usando el respaldo guardado. Tus archivos personales no se tocan.

¿Continuar?"
  [des_fin]="Restauración terminada. Cierra sesión y vuelve a entrar para ver Ubuntu como antes."
)
