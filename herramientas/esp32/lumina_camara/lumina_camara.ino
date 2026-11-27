// =============================================================================
// Lumina Cam — firmware para la Seeed Studio XIAO ESP32S3 Sense
//
// Qué hace:
//   - Crea su propia red Wi-Fi "Lumina-Camara" (funciona en la calle, sin
//     internet ni router). Opcional: conectarse a otra red (ver abajo).
//   - Entrega fotos JPEG por HTTP:   GET /capture
//   - Dice que está viva:            GET /status   (JSON)
//   - Responde a la app cuando la busca por UDP (puerto 4210), así nadie tiene
//     que escribir la dirección IP.
//
// Cómo subirlo (Arduino IDE): ver herramientas/esp32/README.md
//   Placa: "XIAO_ESP32S3"   ·   Tools > PSRAM: "OPI PSRAM"   (¡importante!)
// =============================================================================

#include "esp_camera.h"
#include <WiFi.h>
#include <WebServer.h>
#include <WiFiUdp.h>

// ------------------------- CONFIGURA AQUÍ -----------------------------------
// Red propia que crea la cámara. El teléfono se conecta a ella como a cualquier Wi-Fi.
// ¡CAMBIA LA CLAVE! Con la clave de ejemplo, cualquiera cerca podría ver tu cámara.
// Mínimo 8 caracteres.
const char *AP_NOMBRE = "Lumina-Camara";
const char *AP_CLAVE = "lumina1234";

// OPCIONAL: en vez de crear su red, conectarse a otra (Wi-Fi de casa o el punto
// de acceso del teléfono). Déjalo en "" para usar siempre la red propia.
// Si la pones y no la encuentra en 15 s, igual crea su red propia.
const char *WIFI_NOMBRE = "";
const char *WIFI_CLAVE = "";

// Si la imagen sale al revés o en espejo según cómo montes la cámara, cambia esto.
const bool VOLTEAR_VERTICAL = false;
const bool ESPEJO_HORIZONTAL = false;
// -----------------------------------------------------------------------------

// Pines de la cámara de la XIAO ESP32S3 Sense (mismos que el ejemplo CameraWebServer)
#define PWDN_GPIO_NUM -1
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 10
#define SIOD_GPIO_NUM 40
#define SIOC_GPIO_NUM 39
#define Y9_GPIO_NUM 48
#define Y8_GPIO_NUM 11
#define Y7_GPIO_NUM 12
#define Y6_GPIO_NUM 14
#define Y5_GPIO_NUM 16
#define Y4_GPIO_NUM 18
#define Y3_GPIO_NUM 17
#define Y2_GPIO_NUM 15
#define VSYNC_GPIO_NUM 38
#define HREF_GPIO_NUM 47
#define PCLK_GPIO_NUM 13

#define LED_USUARIO 21 // LED naranjo de la placa (se enciende con LOW)

// Protocolo con la app (debe coincidir con lib/services/fuente_imagen_esp32.dart)
const uint16_t PUERTO_DESCUBRIMIENTO = 4210;
const char *PREGUNTA_APP = "LUMINA?";
const char *RESPUESTA_CAMARA = "LUMINA-CAM";

WebServer servidor(80);
WiFiUDP udp;
bool modoRedPropia = false;
String nombreSensor = "desconocido";
unsigned long ultimoAnuncio = 0;
unsigned long ultimoReintentoWifi = 0;

// -----------------------------------------------------------------------------
// Cámara
// -----------------------------------------------------------------------------

bool iniciarCamara() {
  camera_config_t config = {};
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  // VGA (640x480) basta para el detector (que trabaja a 640) y viaja rápido por Wi-Fi.
  config.frame_size = FRAMESIZE_VGA;
  // 10 = mejor calidad, 63 = peor. Con números bajos la foto puede no caber en
  // el espacio que reserva el driver y sale "cam_hal: FB-OVF" (foto descartada).
  config.jpeg_quality = 15;
  config.fb_count = 2;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  // Siempre la foto más nueva: para guiar, una foto vieja da instrucciones viejas.
  config.grab_mode = CAMERA_GRAB_LATEST;

  if (!psramFound()) {
    Serial.println("AVISO: no hay PSRAM. Activa Tools > PSRAM > OPI PSRAM.");
    config.frame_size = FRAMESIZE_QVGA;
    config.fb_location = CAMERA_FB_IN_DRAM;
    config.fb_count = 1;
  }

  esp_err_t error = esp_camera_init(&config);
  if (error != ESP_OK) {
    Serial.printf("ERROR: la cámara no inició (0x%x). Revisa que esté bien conectada.\n", error);
    return false;
  }

  sensor_t *s = esp_camera_sensor_get();

  // Luz y color automáticos (por si el sensor arrancó con ellos apagados)
  s->set_exposure_ctrl(s, 1); // exposición automática
  s->set_aec2(s, 1);          // exposición automática mejorada (poca luz)
  s->set_gain_ctrl(s, 1);     // ganancia automática
  s->set_whitebal(s, 1);      // balance de blancos automático
  s->set_awb_gain(s, 1);

  switch (s->id.PID) {
    case OV2640_PID: nombreSensor = "OV2640"; break;
    case OV3660_PID:
      nombreSensor = "OV3660";
      // Mismos ajustes que el ejemplo oficial CameraWebServer para este sensor
      s->set_brightness(s, 1);
      s->set_saturation(s, -2);
      break;
    case OV5640_PID: nombreSensor = "OV5640"; break;
    default: nombreSensor = String(s->id.PID, HEX);
  }

  // El OV3660 viene dado vuelta de fábrica: el ejemplo oficial lo endereza
  bool vflip = (s->id.PID == OV3660_PID) ? !VOLTEAR_VERTICAL : VOLTEAR_VERTICAL;
  s->set_vflip(s, vflip ? 1 : 0);
  s->set_hmirror(s, ESPEJO_HORIZONTAL ? 1 : 0);

  // Las primeras fotos salen mal (la cámara aún ajusta la luz): se descartan.
  // Se espera un poco entre ellas para que la exposición automática alcance a ajustarse.
  for (int i = 0; i < 10; i++) {
    camera_fb_t *descarte = esp_camera_fb_get();
    if (descarte) esp_camera_fb_return(descarte);
    delay(100);
  }

  Serial.println("Cámara lista: " + nombreSensor);
  return true;
}

// -----------------------------------------------------------------------------
// Wi-Fi
// -----------------------------------------------------------------------------

void iniciarWifi() {
  WiFi.setSleep(false); // menos demora en cada foto

  bool configurada = strlen(WIFI_NOMBRE) > 0;
  if (configurada) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_NOMBRE, WIFI_CLAVE);
    Serial.printf("Conectando a \"%s\"", WIFI_NOMBRE);

    unsigned long inicio = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - inicio < 15000) {
      digitalWrite(LED_USUARIO, !digitalRead(LED_USUARIO)); // parpadea mientras conecta
      delay(250);
      Serial.print(".");
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.print("Conectada. IP: ");
      Serial.println(WiFi.localIP());
      digitalWrite(LED_USUARIO, LOW); // encendido fijo = conectada
      return;
    }
    Serial.println("No encontré la red configurada.");
  }

  // Red propia. Máximo 2 aparatos conectados: el teléfono y uno de repuesto.
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_NOMBRE, AP_CLAVE, 1, 0, 2);
  modoRedPropia = true;
  Serial.printf("Red propia \"%s\" creada. IP: ", AP_NOMBRE);
  Serial.println(WiFi.softAPIP());
  digitalWrite(LED_USUARIO, LOW);
}

// -----------------------------------------------------------------------------
// Servidor HTTP
// -----------------------------------------------------------------------------

void responderEstado() {
  String json = "{\"lumina\":\"camara\",\"version\":1";
  json += ",\"sensor\":\"" + nombreSensor + "\"";
  json += ",\"modo\":\"" + String(modoRedPropia ? "red_propia" : "wifi") + "\"";
  if (!modoRedPropia) json += ",\"senal\":" + String(WiFi.RSSI());
  json += "}";
  servidor.sendHeader("Cache-Control", "no-store");
  servidor.send(200, "application/json", json);
}

void responderFoto() {
  camera_fb_t *foto = esp_camera_fb_get();
  if (!foto) foto = esp_camera_fb_get(); // un reintento (p. ej. tras un FB-OVF)
  if (!foto) {
    servidor.send(503, "text/plain", "No pude tomar la foto");
    return;
  }
  // Diagnóstico: una foto negra pesa muy poco (3-6 KB); una normal, 15 KB o más.
  static unsigned long ultimoInforme = 0;
  if (millis() - ultimoInforme > 3000) {
    ultimoInforme = millis();
    Serial.printf("Foto %ux%u: %u KB%s\n", foto->width, foto->height,
                  (unsigned)(foto->len / 1024),
                  foto->len < 8000 ? "  <- muy liviana: ¿imagen negra o tapada?" : "");
  }

  servidor.sendHeader("Cache-Control", "no-store");
  servidor.setContentLength(foto->len);
  servidor.send(200, "image/jpeg", "");
  servidor.client().write(foto->buf, foto->len);
  esp_camera_fb_return(foto);
}

// -----------------------------------------------------------------------------
// Descubrimiento por UDP: la app pregunta "LUMINA?" y la cámara responde.
// Además, cada 2 s la cámara se anuncia sola a toda la red.
// -----------------------------------------------------------------------------

void atenderDescubrimiento() {
  int largo = udp.parsePacket();
  if (largo > 0) {
    char mensaje[32] = {0};
    udp.read(mensaje, sizeof(mensaje) - 1);
    if (strncmp(mensaje, PREGUNTA_APP, strlen(PREGUNTA_APP)) == 0) {
      udp.beginPacket(udp.remoteIP(), udp.remotePort());
      udp.print(RESPUESTA_CAMARA);
      udp.endPacket();
    }
  }

  if (millis() - ultimoAnuncio > 2000) {
    ultimoAnuncio = millis();
    IPAddress difusion = modoRedPropia ? WiFi.softAPBroadcastIP() : WiFi.broadcastIP();
    udp.beginPacket(difusion, PUERTO_DESCUBRIMIENTO);
    udp.print(RESPUESTA_CAMARA);
    udp.endPacket();
  }
}

// -----------------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  pinMode(LED_USUARIO, OUTPUT);
  digitalWrite(LED_USUARIO, HIGH); // apagado

  if (!iniciarCamara()) {
    // Sin cámara no tiene sentido seguir: parpadeo rápido para avisar
    while (true) {
      digitalWrite(LED_USUARIO, !digitalRead(LED_USUARIO));
      delay(100);
    }
  }

  iniciarWifi();

  servidor.on("/status", HTTP_GET, responderEstado);
  servidor.on("/capture", HTTP_GET, responderFoto);
  servidor.onNotFound([]() { servidor.send(404, "text/plain", "Usa /capture o /status"); });
  servidor.begin();

  udp.begin(PUERTO_DESCUBRIMIENTO);
  Serial.println("Lumina Cam lista.");
}

void loop() {
  servidor.handleClient();
  atenderDescubrimiento();

  // Si se cayó el Wi-Fi (el teléfono se alejó), reintenta cada 5 s
  if (!modoRedPropia && WiFi.status() != WL_CONNECTED &&
      millis() - ultimoReintentoWifi > 5000) {
    ultimoReintentoWifi = millis();
    digitalWrite(LED_USUARIO, HIGH);
    WiFi.reconnect();
  } else if (!modoRedPropia && WiFi.status() == WL_CONNECTED) {
    digitalWrite(LED_USUARIO, LOW);
  }

  delay(2);
}
