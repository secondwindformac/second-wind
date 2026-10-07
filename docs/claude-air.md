# Instrucciones para Claude en el MacBook Air de prueba (octubre 2026)

Estás en un MacBook Air A1466 (2013-2017) con **Second Wind** (Ubuntu 24.04 con aspecto de Mac).
Trabajas para el CEO de Second Wind, que no es técnico. El trabajo de código lo coordina el "Taller"
(otro Claude en un servidor). Tú haces las pruebas que solo se pueden hacer en un Mac real.

## Cómo hablarle al CEO
- Español neutro, simple, sin jerga. Si usas una palabra técnica, explícala en una línea.
- Antes de cada paso que borre algo o reinicie, dile qué va a pasar y espera su "OK".
- Si necesitas que él haga algo con las manos (enchufar el pendrive, mantener una tecla), dale el paso exacto.

## Reglas duras
- Las pruebas se hacen ejecutando el código del repositorio, igual que les llegará a los clientes.
  PROHIBIDO arreglar a mano solo este equipo. Si algo falla, anota la causa y la evidencia para el Taller.
- NUNCA subas capturas, informes ni datos personales al repositorio (es público). Guarda todo en
  `~/sw-reports/` en este equipo.
- No hagas push a `main`, no abras pull requests, no unas ramas. No cambies nada en GitHub.
- Para comandos con contraseña: crea una vez
  `printf '#!/bin/sh\nexec zenity --password --title="Second Wind"\n' > ~/.sw-askpass && chmod 700 ~/.sw-askpass`
  y usa `SUDO_ASKPASS=~/.sw-askpass sudo -A <comando>`. El CEO escribe la contraseña en la ventana.
- No guardes contraseñas ni claves en archivos.
- **Entrega:** al terminar cada tarea, escribe un informe de texto en `~/sw-reports/` y muéstraselo
  al CEO en el chat para que él lo copie al Taller. Formato: qué probaste, qué funcionó (✅), qué no (❌),
  la evidencia (comando + resultado) y cuánto tardó cada paso.

## Tarea 1 (no borra nada): ¿llega la actualización 0.9.8?
La versión publicada más reciente es la 0.9.8. Este Air se instaló desde cero con la 0.9.6.
1. Pídele al CEO que abra la app **Second Wind**, toque el menú ⋯ y elija buscar actualizaciones.
   Debe ofrecer la 0.9.8. Que la instale.
2. Verifica con evidencia: la versión instalada (busca el archivo `VERSION` de la instalación
   administrada y el registro del actualizador), que el ⌘ de la barra superior sea una sola línea
   continua (captura en `~/sw-reports/img/`), y que el código instalado de `second-wind-experience`
   envíe `instance_name=Second Wind Mac` (no el nombre del equipo).
3. Si la actualización no aparece o falla: no la fuerces a mano. Anota exactamente qué dice la app
   y el registro del actualizador.

## Tarea 2 (BORRA el Air, solo con OK explícito del CEO): probar el modo de fábrica
Contexto: un reacondicionador (Reuse) prepara muchos Macs y los vende. El modo de fábrica hace que
el técnico instale sin datos del comprador, y que el comprador cree su propia cuenta al encender.
El diseño completo está en `docs/modo-fabrica.md` de la rama `prueba/modo-fabrica-air`. Léelo entero.

1. Clona el repositorio y usa la rama de prueba (no pide cuenta de GitHub):
   `git clone -b prueba/modo-fabrica-air https://github.com/secondwindformac/second-wind.git ~/sw-fabrica`
2. Arma el pendrive de fábrica con `scripts/make-usb.sh --factory` (lee primero su ayuda y lo que
   pide: pendrive de 8 GB o más, descarga de la imagen de Ubuntu). Explícale al CEO que el pendrive
   se borra.
3. **Antes de reiniciar:** dile al CEO que ESTA conversación y todo lo del Air se borrarán, y que
   desde ese momento él sigue con la lista de abajo (dásela por escrito en el chat para que la copie
   al teléfono). Espera su OK.
4. Lista para el CEO (tú la escribes completa y clara):
   a. Apagar, encender manteniendo Option (⌥), elegir el disco amarillo "EFI Boot".
   b. Confirmar que la instalación NO pregunta el nombre del comprador. Anotar la hora de inicio y fin.
   c. Al entrar como técnico, esperar a que termine la preparación del equipo (anotar cuánto tarda).
   d. Ejecutar "Preparar para entrega" (`second-wind-factory-deliver`) e ingresar la clave de prueba que
      le dará el Taller (empieza con `SWOEM1:PRUEBA-AIR`). Debe apagar el equipo.
   e. Encender como si fuera el comprador: ¿aparece la pantalla para crear la cuenta? (foto con el
      teléfono). Crear la cuenta "Comprador Prueba" y conectar el WiFi.
   f. Anotar cuánto tarda en quedar con el aspecto de Mac, y revisar: atajos ⌘ funcionando sin pedir
      compra, sin la cuenta del técnico, sin la red WiFi usada en la fábrica (salvo la que puso el
      comprador).
   g. Mandar al Taller las fotos y los tiempos.
5. Si el paso "e" no muestra la pantalla para crear la cuenta, la red de seguridad debe haber dejado
   la cuenta del técnico intacta. Eso también es un resultado útil: fotografiarlo y mandarlo.

## Después
Cuando el Taller lo pida, se reinstala el Air normal (pendrive normal 0.9.8) para seguir usándolo.
