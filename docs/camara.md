# Cámara FaceTime HD

Las MacBook 2013-2017 usan una cámara (Broadcom 1570) que Linux no trae de
fábrica. MacConLinux instala el driver comunitario
[facetimehd](https://github.com/patjak/facetimehd) mediante DKMS (se recompila
solo con cada kernel nuevo) y extrae el firmware de la cámara **localmente**
desde un paquete oficial de Apple (el firmware es de Apple y no puede
redistribuirse; por eso se extrae en tu equipo).

## Si el instalador dijo "la cámara no pudo activarse"

1. No pasa nada: el instalador revirtió todo lo relacionado con la cámara y
   el resto de MacConLinux quedó funcionando.
2. Causas típicas: el kernel es tan nuevo que el driver aún no lo soporta, o
   no se pudo descargar el paquete de firmware.
3. Reintenta tras actualizar el sistema:

   ```bash
   ./install.sh --solo hardware
   ```

## Comprobar si funciona

```bash
ls /dev/video0
```

Si existe, abre la app "Cámara" de Ubuntu (o cualquier videollamada). Si el
driver quedó instalado pero `/dev/video0` no aparece, reinicia el equipo.
