# Cómo volver a Ubuntu tal como estaba

```bash
cd MacConLinux
./uninstall.sh
```

Qué hace: usando el **manifiesto de cambios** (cada ajuste guardó su valor
original la primera vez que se tocó), repone uno a uno los ajustes del
escritorio, quita las extensiones y archivos que MacConLinux creó, y — si
instalaste el módulo de hardware — revierte también el driver de la cámara,
mbpfan y demás (te pedirá la contraseña de administrador).

Después cierra sesión y vuelve a entrar.

Opciones extra:

| Comando | Qué añade |
|---|---|
| `./uninstall.sh --purgar-temas` | Borra también del disco los temas/iconos MacTahoe (libera ~400 MB) |
| `./uninstall.sh --dconf-completo` | Último recurso: repone TODA la configuración del escritorio tal como estaba el día del respaldo (pisa cualquier ajuste que hayas hecho después) |

Notas:

- Tus archivos personales nunca se tocan.
- Toshy (el servicio de teclado) no se desinstala porque MacConLinux no lo
  instaló en este equipo; solo se repone su icono de bandeja. Para quitarlo:
  `~/Toshy/setup_toshy.py remove` (o consulta su documentación).
- El respaldo original queda en `~/.local/state/macconlinux/backup/pristine/`
  por si lo necesitas.
