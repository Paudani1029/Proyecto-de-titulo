package com.example.lumina

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Temperatura del teléfono para el banco de pruebas (lib/services/banco_pruebas.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumina/termico")
            .setMethodCallHandler { llamada, resultado ->
                if (llamada.method == "estado") {
                    resultado.success(leerEstadoTermico())
                } else {
                    resultado.notImplemented()
                }
            }

        // Lumina Cam con red propia (lib/services/red_wifi_local.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumina/red")
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    "usarWifi" -> resultado.success(usarWifi())
                    "soltarWifi" -> {
                        soltarWifi()
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            }
    }

    /**
     * La red "Lumina-Camara" no tiene internet, así que Android sigue usando los
     * datos móviles y la app no llega a la cámara (192.168.4.1). Esto hace que
     * SOLO esta app use el Wi-Fi. El resto del teléfono (y el reconocimiento de
     * voz de Google) sigue con datos móviles.
     */
    @Suppress("DEPRECATION") // allNetworks: simple y funciona en todas las versiones
    private fun usarWifi(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val conectividad = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val wifi = conectividad.allNetworks.firstOrNull { red ->
            conectividad.getNetworkCapabilities(red)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        } ?: return false
        return conectividad.bindProcessToNetwork(wifi)
    }

    private fun soltarWifi() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val conectividad = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        conectividad.bindProcessToNetwork(null)
    }

    private fun leerEstadoTermico(): Map<String, Any?> {
        val energia = getSystemService(Context.POWER_SERVICE) as PowerManager

        // 0 = normal ... 6 = apagado (Android 10+)
        val estado = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            energia.currentThermalStatus
        } else {
            -1
        }

        // 1.0 = el sistema está por bajar la velocidad del procesador (Android 11+).
        // Devuelve NaN si el teléfono no lo soporta.
        val margen: Double? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            energia.getThermalHeadroom(10).toDouble().takeUnless { it.isNaN() }
        } else {
            null
        }

        // Temperatura de la batería en décimas de °C. Funciona en todos los teléfonos.
        val bateria = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val decimas = bateria?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val bateriaC = if (decimas == null || decimas == Int.MIN_VALUE) null else decimas / 10.0

        return mapOf("estado" to estado, "margen" to margen, "bateria" to bateriaC)
    }
}
