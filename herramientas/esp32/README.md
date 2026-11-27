# Lumina Cam (XIAO ESP32S3 Sense)

Firmware para usar la cámara de la XIAO ESP32S3 Sense en vez de la del teléfono.
La cámara crea **su propia red Wi-Fi**, así funciona en la calle, sin router ni internet.
La app le pide fotos por esa red y las analiza igual que las del teléfono.

## 1. Preparar Arduino IDE

1. **Archivo > Preferencias > Gestor de URLs adicionales de tarjetas**, agrega:
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
2. **Herramientas > Placa > Gestor de tarjetas**: instala **esp32** (de Espressif).
3. **Herramientas > Placa**: elige **XIAO_ESP32S3**.
4. **Herramientas > PSRAM**: elige **OPI PSRAM**. Sin esto la cámara funciona con
   menos calidad (o no inicia).

## 2. Cambiar la clave

Abre `lumina_camara/lumina_camara.ino` (Archivo > Abrir) y cambia la clave:

```cpp
const char *AP_NOMBRE = "Lumina-Camara";
const char *AP_CLAVE = "lumina1234";   // <- pon una tuya (mínimo 8 caracteres)
```

**Importante:** con la clave de ejemplo, cualquier persona cerca podría conectarse
y ver lo que ve la cámara.

## 3. Subir y probar

1. Conecta la placa por USB-C y presiona **Subir**.
2. Abre el **Monitor Serie** (115200 baudios). Debe decir:
   ```
   Cámara lista: OV2640
   Red propia "Lumina-Camara" creada. IP: 192.168.4.1
   Lumina Cam lista.
   ```
3. En el teléfono, conéctate al Wi-Fi **Lumina-Camara** con tu clave.
   - Android dirá *"La red no tiene acceso a internet"*: elige **Mantener conexión**
     (o "No volver a preguntar"). Así se reconecta sola la próxima vez.
4. Abre en el navegador del teléfono `http://192.168.4.1/capture`: debe verse una foto.
   (Si el navegador no carga, apaga los datos móviles solo para esta prueba;
   la app no lo necesita.)

**LED naranjo de la placa:** parpadea = conectando · encendido = lista ·
parpadeo muy rápido = la cámara no inició (revisa el conector de la cámara).

## 4. Usarla en la app

**Ajustes > Cámara > Lumina Cam.** La app la encuentra sola y recuerda la elección.

Mientras usa la red de la cámara, **la app no tiene internet** (los ajustes no se
sincronizan con la nube hasta volver a la cámara del teléfono). La detección, la
voz y los comandos de voz siguen funcionando, y el resto del teléfono mantiene sus
datos móviles.

Si al guiar las indicaciones de izquierda/derecha salen invertidas, o la foto sale
de cabeza, cambia `ESPEJO_HORIZONTAL` o `VOLTEAR_VERTICAL` en el firmware.

## Opcional: conectarla a otra red

Si prefieres que la cámara se conecte al Wi-Fi de tu casa o al punto de acceso del
teléfono (así la app conserva internet), pon esa red en:

```cpp
const char *WIFI_NOMBRE = "MiRed";
const char *WIFI_CLAVE = "MiClave";
```

La red debe ser de **2,4 GHz** (la ESP32 no ve redes de 5 GHz). Si no la encuentra
en 15 s, igual crea su red propia. La app la busca sola en cualquiera de los dos casos.

## Protocolo (por si cambias algo)

| Qué | Cómo |
|---|---|
| Foto | `GET /capture` → `image/jpeg` (640x480) |
| Estado | `GET /status` → `{"lumina":"camara","version":1,"sensor":"OV2640","modo":"red_propia"}` |
| Búsqueda | La app envía `LUMINA?` por UDP al puerto `4210`; la cámara responde `LUMINA-CAM`. Además se anuncia cada 2 s. |

Debe coincidir con [lib/services/fuente_imagen_esp32.dart](../../lib/services/fuente_imagen_esp32.dart).
