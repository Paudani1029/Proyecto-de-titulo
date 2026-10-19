import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Versión del esquema. Incrementar al cambiar tablas y añadir migración en onUpgrade.
const int kSchemaVersion = 1;

const _schemaV1 = <String>[
  // Una fila por cada vez que se abre la app y se conecta la cámara.
  '''
  CREATE TABLE sessions (
    id              TEXT PRIMARY KEY,
    started_at_ms   INTEGER NOT NULL,
    ended_at_ms     INTEGER,
    device_model    TEXT NOT NULL,
    app_version     TEXT NOT NULL,
    model_version   TEXT NOT NULL
  )
  ''',

  // Detecciones estructuradas (tipo, distancia, velocidad).
  // Vacía por ahora: reconocimiento_service.dart aún no separa esto,
  // solo entrega un texto con las etiquetas. Queda lista para cuando
  // se agregue distancia/velocidad/tipo de objeto.
  '''
  CREATE TABLE detection_events (
    id                    TEXT PRIMARY KEY,
    session_id            TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    kind                  TEXT NOT NULL CHECK (kind IN ('obstacle','person','animal','object')),
    label                 TEXT,
    confidence            REAL NOT NULL CHECK (confidence BETWEEN 0 AND 1),
    distance_m            REAL,
    approach_speed_mps    REAL,
    frame_timestamp_ms    INTEGER NOT NULL,
    created_at_ms         INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_detections_session_time ON detection_events(session_id, frame_timestamp_ms)',

  // Esto sí se llena desde el día uno: cada texto que voz_service.dart narra.
  '''
  CREATE TABLE alerts (
    id                    TEXT PRIMARY KEY,
    session_id            TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    detection_event_id    TEXT REFERENCES detection_events(id) ON DELETE SET NULL,
    message               TEXT NOT NULL,
    source                TEXT NOT NULL CHECK (source IN ('offline','ai')),
    frame_timestamp_ms    INTEGER NOT NULL,
    tts_started_at_ms     INTEGER NOT NULL,
    latency_ms            INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_alerts_session_time ON alerts(session_id, tts_started_at_ms)',

  // Vacía por ahora: todavía no hay llamadas a IA por API (OCR, descripciones avanzadas).
  '''
  CREATE TABLE ai_queries (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    query_type        TEXT NOT NULL CHECK (query_type IN ('ocr','description')),
    response_time_ms  INTEGER,
    status            TEXT NOT NULL CHECK (status IN ('success','offline','error')),
    created_at_ms     INTEGER NOT NULL
  )
  ''',

  // Feedback del usuario de prueba sobre cada alerta hablada.
  '''
  CREATE TABLE feedback (
    id              TEXT PRIMARY KEY,
    alert_id        TEXT NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
    rating          TEXT NOT NULL CHECK (rating IN ('useful','false_positive','late','unnecessary')),
    created_at_ms   INTEGER NOT NULL
  )
  ''',
];

class LuminaDb {
  LuminaDb._(this.db);
  final Database db;

  static Future<LuminaDb> open({String? path}) async {
    final dbPath = path ?? join(await getDatabasesPath(), 'lumina.db');
    final database = await openDatabase(
      dbPath,
      version: kSchemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final sql in _schemaV1) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migraciones futuras: if (oldVersion < 2) { ... }
      },
    );
    return LuminaDb._(database);
  }

  Future<void> close() => db.close();
}