import 'services/camara_service.dart';
import 'services/phone_camera_service.dart';
//import 'services/mock_camara_service.dart';
import 'services/voz_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistencia Visual',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

/////// 
///
class _PantallaPrincipalState extends State<PantallaPrincipal> {
  bool _escuchando = true;
  bool _conectada = false;
  String _descripcionActual = 'Conectando con la cámara...';

  final VozService _voz = VozService();

  final CameraService _servicioCamara = PhoneCameraService();
  StreamSubscription<String>? _suscripcion;

  @override
  void initState() {
    super.initState();
    _iniciarConexion();
  }

  Future<void> _iniciarConexion() async {
  final exito = await _servicioCamara.conectar();
  if (exito) {
    setState(() {
      _conectada = true;
      _descripcionActual = 'Cámara conectada. Esperando datos...';
    });

    _suscripcion = _servicioCamara.descripciones.listen((texto) {
      setState(() {
        _descripcionActual = texto;
      });

      if (_escuchando) {
        _voz.hablar(texto);
        }
      });
    }
  }

  void _alternarEscucha() {
  setState(() {
    _escuchando = !_escuchando;
  });

  if (!_escuchando) {
    _voz.detener();
  }
}

  @override
  void dispose() {
    _suscripcion?.cancel();
    _servicioCamara.desconectar();
    _voz.detener();
    super.dispose();
  }

  // solo cambia el Text del recuadro de descripción:


  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          if (_conectada)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Cámara conectada',
                      style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ),
          // Espacio flexible arriba y el círculo central
          Expanded(
            child: GestureDetector(
              onTap: _alternarEscucha,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(
                        _escuchando ? Icons.mic : Icons.mic_off,
                        size: 50,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _escuchando ? 'Escuchando el entorno' : 'En pausa',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toca en cualquier parte para pausar',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Recuadro con la descripción simulada
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.volume_up, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _descripcionActual,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Fila de botones inferiores
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _botonInferior(Icons.pause, 'Pausar'),
                _botonInferior(Icons.repeat, 'Repetir'),
                _botonInferior(Icons.help_outline, 'Ayuda'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Función auxiliar para no repetir código en cada botón
Widget _botonInferior(IconData icono, String etiqueta) {
  return Column(
    children: [
      Icon(icono, color: Colors.grey.shade700),
      const SizedBox(height: 4),
      Text(
        etiqueta,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    ],
  );
 }
}