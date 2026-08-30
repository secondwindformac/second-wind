#!/usr/bin/env bash
# 60-hardware — arreglos de hardware para MacBooks Intel. ÚNICO módulo con sudo.
#   1. mbpfan: control inteligente del ventilador (los Mac con Linux suelen
#      quedarse con el ventilador al mínimo aunque la CPU esté caliente).
#   2. Persistencia del modo de las teclas F (hid_apple fnmode).
#   3. Cámara FaceTime HD: driver DKMS de terceros + firmware extraído de Apple.
#      Con rollback total: si no compila con este kernel, se limpia y el resto
#      de la instalación no se ve afectado.
#   4. Opcional: desactivar el autologin para que el llavero no moleste.

if [ "$DRY_RUN" = 1 ]; then
  info "HARÍA: instalar mbpfan, persistir el modo de las teclas F y activar la cámara FaceTime HD (con sudo)"
  return 0
fi

info "Este paso necesita tu contraseña de administrador."
if ! sudo -v; then
  warn "No hay permisos de administrador; el módulo de hardware se omite (puedes repetirlo luego con ./install.sh --solo hardware)."
  return 1
fi
# Mantener sudo vivo mientras dura el módulo
( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &
MCL_SUDO_KEEPALIVE=$!
trap 'kill "$MCL_SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

# Instala un paquete solo si falta, y lo registra para poder desinstalarlo.
apt_track_install() {
  local p
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 && continue
    if sudo apt-get install -y "$p" >/dev/null 2>&1; then
      mf apt-installed "$p"
    else
      warn "No se pudo instalar el paquete $p"
      return 1
    fi
  done
}

sudo apt-get update -qq 2>/dev/null || warn "No se pudo refrescar la lista de paquetes; se sigue con lo disponible"

# --- 1) Ventilador ---
info "Ventilador: instalando control inteligente (mbpfan)…"
if apt_track_install mbpfan; then
  sudo systemctl enable --now mbpfan >/dev/null 2>&1 \
    && ok "mbpfan activo: el ventilador ahora responde a la temperatura real" \
    || warn "mbpfan instalado pero su servicio no arrancó (revisa 'systemctl status mbpfan')"
else
  warn "Sin mbpfan: el ventilador seguirá en modo automático básico"
fi

# --- 2) Teclas F persistentes ---
FN="$(cat /sys/module/hid_apple/parameters/fnmode 2>/dev/null || echo 3)"
CONF=/etc/modprobe.d/macconlinux-hid_apple.conf
if [ ! -f "$CONF" ]; then
  info "Teclas F: fijando el comportamiento actual (fnmode=$FN) para que sobreviva a los reinicios…"
  sed "s/@FNMODE@/$FN/" "$MCL_ROOT/assets/modprobe/macconlinux-hid_apple.conf.tpl" \
    | sudo tee "$CONF" >/dev/null
  mf system-file "$CONF"
  sudo update-initramfs -u >/dev/null 2>&1 || warn "update-initramfs falló (no crítico: el ajuste aplica igual al cargar el módulo)"
fi

# --- 3) Cámara FaceTime HD ---
if [ -e /dev/video0 ]; then
  ok "La cámara ya funciona; no se toca."
else
  info "Cámara FaceTime HD: preparando el driver (3-6 minutos)…"
  if apt_track_install "linux-headers-$(uname -r)" build-essential dkms; then
    CAM_OK=0
    if clone_pinned "$FTHD_FW_REPO" "$MCL_CACHE/facetimehd-firmware" "$FTHD_FW_SHA" \
       && clone_pinned "$FTHD_REPO" "$MCL_CACHE/facetimehd" "$FTHD_SHA"; then

      # Firmware: se extrae de un paquete oficial de Apple, localmente (no se redistribuye)
      if ( cd "$MCL_CACHE/facetimehd-firmware" && make >/dev/null 2>&1 \
           && sudo make install >/dev/null 2>&1 ); then
        mf system-file /usr/lib/firmware/facetimehd/firmware.bin

        # Driver vía DKMS (se recompila solo con cada kernel nuevo)
        VER="0.1"
        [ -f "$MCL_CACHE/facetimehd/dkms.conf" ] \
          && VER="$(sed -n 's/^PACKAGE_VERSION="\?\([^"]*\)"\?/\1/p' "$MCL_CACHE/facetimehd/dkms.conf" | head -1)"
        [ -n "$VER" ] || VER="0.1"
        SRC="/usr/src/facetimehd-$VER"
        sudo rsync -a --delete --exclude=.git "$MCL_CACHE/facetimehd/" "$SRC/"
        if [ ! -f "$SRC/dkms.conf" ]; then
          printf 'PACKAGE_NAME="facetimehd"\nPACKAGE_VERSION="%s"\nBUILT_MODULE_NAME[0]="facetimehd"\nDEST_MODULE_LOCATION[0]="/extra"\nAUTOINSTALL="yes"\nMAKE[0]="make KDIR=/lib/modules/${kernelver}/build"\nCLEAN="make clean"\n' "$VER" \
            | sudo tee "$SRC/dkms.conf" >/dev/null
        fi
        sudo dkms add -m facetimehd -v "$VER" >/dev/null 2>&1 || true
        if sudo dkms build -m facetimehd -v "$VER" >/dev/null 2>&1 \
           && sudo dkms install -m facetimehd -v "$VER" >/dev/null 2>&1; then
          sudo modprobe facetimehd 2>/dev/null || true
          sleep 2
          mf dkms-installed "facetimehd/$VER"
          if [ -e /dev/video0 ]; then
            ok "¡Cámara FaceTime HD activada! (/dev/video0)"
            CAM_OK=1
          else
            warn "Driver de cámara instalado; se activará tras reiniciar el equipo"
            CAM_OK=1
          fi
        else
          warn "El driver de la cámara no compiló con el kernel $(uname -r). Se revierte todo lo de la cámara; el resto no se ve afectado (detalles en docs/camara.md)."
          sudo dkms remove -m facetimehd -v "$VER" --all >/dev/null 2>&1 || true
          sudo rm -rf "$SRC"
        fi
      else
        warn "No se pudo extraer el firmware de la cámara (¿sin internet a los servidores de Apple?). La cámara queda pendiente."
      fi
    else
      warn "No se pudieron descargar las fuentes del driver de cámara."
    fi
    [ "$CAM_OK" = 1 ] || mf note "camara-pendiente"
  else
    warn "Faltan herramientas de compilación; la cámara queda pendiente."
  fi
fi

# --- 4) Autologin / llavero (solo si hay terminal y el autologin está activo) ---
if [ "$ASSUME_YES" != 1 ] && ui_has_tty \
   && grep -q '^AutomaticLoginEnable\s*=\s*[Tt]rue' /etc/gdm3/custom.conf 2>/dev/null; then
  if ui_yesno "${MSG[preg_autologin]}" --default-no; then
    sudo sed -i 's/^\(AutomaticLoginEnable\s*=\s*\)[Tt]rue/\1false/' /etc/gdm3/custom.conf
    mf system-file /etc/gdm3/custom.conf
    ok "Inicio de sesión automático desactivado (respaldo del archivo original guardado)"
  fi
fi

kill "$MCL_SUDO_KEEPALIVE" 2>/dev/null || true
trap - EXIT
