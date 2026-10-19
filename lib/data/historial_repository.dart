import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'lumina_db.dart';

const _uuid = Uuid();
int ahoraMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

class HistorialRepository {
  HistorialRepository(this._db);
  final LuminaDb _db;
  Database get _sql => _db.db;

  Future<String> iniciarSesion({
    required String deviceModel,
    required String appVersion,
    required String modelVersion,
  }) async {
    final id = _uuid.v4();
    await _sql.insert('sessions', {
      'id': id,
      'started_at_ms': ahoraMs(),
      'device_model': deviceModel,
      'app_version': appVersion,
      'model_version': modelVersion,
    });
    return id;
  }

  Future<void> finalizarSesion(String sessionId) => _sql.update(
        'sessions',
        {'ended_at_ms': ahoraMs()},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

  /// [frameTimestampMs] = cuando se tomó la foto (XFile.path capturado).
  /// [ttsStartedAtMs] = cuando voz_service.dart empezó a hablar el texto.
  Future<String> registrarAlerta({
    required String sessionId,
    required String message,
    required String source, // 'offline' por ahora, siempre
    required int frameTimestampMs,
    required int ttsStartedAtMs,
  }) async {
    final id = _uuid.v4();
    await _sql.insert('alerts', {
      'id': id,
      'session_id': sessionId,
      'message': message,
      'source': source,
      'frame_timestamp_ms': frameTimestampMs,
      'tts_started_at_ms': ttsStartedAtMs,
      'latency_ms': ttsStartedAtMs - frameTimestampMs,
    });
    return id;
  }

  Future<void> registrarFeedback({
    required String alertId,
    required String rating, // 'useful' | 'false_positive' | 'late' | 'unnecessary'
  }) async {
    await _sql.insert('feedback', {
      'id': _uuid.v4(),
      'alert_id': alertId,
      'rating': rating,
      'created_at_ms': ahoraMs(),
    });
  }

  /// Latencia promedio/máxima de las alertas de una sesión, para revisar pruebas.
  Future<List<Map<String, Object?>>> resumenSesion(String sessionId) {
    return _sql.rawQuery('''
      SELECT COUNT(*) AS total,
             AVG(latency_ms) AS avg_latency_ms,
             MAX(latency_ms) AS max_latency_ms
      FROM alerts
      WHERE session_id = ?
    ''', [sessionId]);
  }
}