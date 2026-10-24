import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/live_sample.dart';

class BenchmarkDatabaseService {
  BenchmarkDatabaseService({Database? db}) {
    _db = db;
    if (_db != null) {
      _initSchema();
    }
  }

  Database? _db;
  Database get db => _db!;

  /// Opens the database file in application support directory or in-memory.
  Future<void> init({bool inMemory = false}) async {
    if (_db != null) return;

    if (inMemory) {
      _db = sqlite3.openInMemory();
    } else {
      final appSupportDir = await getApplicationSupportDirectory();
      final dbPath = p.join(appSupportDir.path, 'net_bench', 'net_bench.db');
      final dbFile = File(dbPath);
      if (!await dbFile.parent.exists()) {
        await dbFile.parent.create(recursive: true);
      }
      _db = sqlite3.open(dbPath);
    }
    _initSchema();
  }

  void _initSchema() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS test_runs (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        profile_name TEXT NOT NULL,
        target_host TEXT NOT NULL,
        port INTEGER NOT NULL,
        protocol TEXT NOT NULL,
        direction TEXT NOT NULL,
        streams INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        avg_throughput_mbps REAL NOT NULL,
        peak_throughput_mbps REAL NOT NULL,
        min_throughput_mbps REAL NOT NULL,
        total_bytes INTEGER NOT NULL,
        jitter_ms REAL,
        loss_percent REAL,
        lost_packets INTEGER,
        total_packets INTEGER,
        retransmits INTEGER NOT NULL,
        baseline_ping_ms REAL,
        loaded_ping_ms REAL,
        bufferbloat_delta_ms REAL,
        samples_json TEXT NOT NULL,
        raw_json TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_runs_timestamp ON test_runs(timestamp);
      CREATE INDEX IF NOT EXISTS idx_runs_target ON test_runs(target_host);
      CREATE INDEX IF NOT EXISTS idx_runs_protocol ON test_runs(protocol);
      CREATE INDEX IF NOT EXISTS idx_runs_profile ON test_runs(profile_name);

      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
  }

  String? getSetting(String key) {
    final rs = _db!.select('SELECT value FROM app_settings WHERE key = ?', [key]);
    if (rs.isEmpty) return null;
    return rs.first['value'] as String?;
  }

  void setSetting(String key, String value) {
    final stmt = _db!.prepare('''
      INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)
    ''');
    try {
      stmt.execute([key, value]);
    } finally {
      stmt.close();
    }
  }

  /// Inserts or replaces a benchmark run in the database.
  void saveResult(BenchmarkResult res) {
    final stmt = _db!.prepare('''
      INSERT OR REPLACE INTO test_runs (
        id, timestamp, profile_name, target_host, port, protocol, direction,
        streams, duration_seconds, avg_throughput_mbps, peak_throughput_mbps,
        min_throughput_mbps, total_bytes, jitter_ms, loss_percent, lost_packets,
        total_packets, retransmits, baseline_ping_ms, loaded_ping_ms,
        bufferbloat_delta_ms, samples_json, raw_json, status, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    try {
      stmt.execute([
        res.id,
        res.timestamp.toIso8601String(),
        res.profileName,
        res.targetHost,
        res.port,
        res.protocol,
        res.direction,
        res.streams,
        res.durationSeconds,
        res.avgThroughputMbps,
        res.peakThroughputMbps,
        res.minThroughputMbps,
        res.totalBytes,
        res.jitterMs,
        res.lossPercent,
        res.lostPackets,
        res.totalPackets,
        res.retransmits,
        res.baselinePingMs,
        res.loadedPingMs,
        res.bufferbloatDeltaMs,
        jsonEncode(res.samples.map((s) => s.toMap()).toList()),
        res.rawJson,
        res.status,
        res.errorMessage,
      ]);
    } finally {
      stmt.close();
    }
  }

  /// Queries paginated historical benchmark runs with optional search & protocol filter.
  List<BenchmarkResult> getRuns({
    int limit = 100,
    int offset = 0,
    String? searchQuery,
    String? protocol,
  }) {
    final conditions = <String>[];
    final params = <dynamic>[];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      conditions.add('(target_host LIKE ? OR profile_name LIKE ?)');
      params.add(term);
      params.add(term);
    }

    if (protocol != null && protocol.isNotEmpty && protocol.toUpperCase() != 'ALL') {
      conditions.add('UPPER(protocol) = ?');
      params.add(protocol.toUpperCase());
    }

    final whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final sql = '''
      SELECT * FROM test_runs
      $whereClause
      ORDER BY timestamp DESC
      LIMIT ? OFFSET ?
    ''';
    params.add(limit);
    params.add(offset);

    final resultSet = _db!.select(sql, params);
    return resultSet.map((row) => _fromRow(row)).toList();
  }

  BenchmarkResult? getRunById(String id) {
    final rs = _db!.select('SELECT * FROM test_runs WHERE id = ?', [id]);
    if (rs.isEmpty) return null;
    return _fromRow(rs.first);
  }

  void deleteRun(String id) {
    _db!.execute('DELETE FROM test_runs WHERE id = ?', [id]);
  }

  void clearAllRuns() {
    _db!.execute('DELETE FROM test_runs');
  }

  int getRunCount() {
    final rs = _db!.select('SELECT COUNT(*) as count FROM test_runs');
    return rs.first['count'] as int? ?? 0;
  }

  BenchmarkResult _fromRow(Row row) {
    List<LiveSample> sampleList = [];
    final rawSamples = row['samples_json'] as String?;
    if (rawSamples != null && rawSamples.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSamples) as List<dynamic>;
        sampleList = decoded
            .map((item) => LiveSample.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return BenchmarkResult(
      id: row['id'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      profileName: row['profile_name'] as String,
      targetHost: row['target_host'] as String,
      port: row['port'] as int,
      protocol: row['protocol'] as String,
      direction: row['direction'] as String,
      streams: row['streams'] as int,
      durationSeconds: row['duration_seconds'] as int,
      avgThroughputMbps: (row['avg_throughput_mbps'] as num).toDouble(),
      peakThroughputMbps: (row['peak_throughput_mbps'] as num).toDouble(),
      minThroughputMbps: (row['min_throughput_mbps'] as num).toDouble(),
      totalBytes: row['total_bytes'] as int,
      jitterMs: (row['jitter_ms'] as num?)?.toDouble(),
      lossPercent: (row['loss_percent'] as num?)?.toDouble(),
      lostPackets: row['lost_packets'] as int?,
      totalPackets: row['total_packets'] as int?,
      retransmits: row['retransmits'] as int,
      baselinePingMs: (row['baseline_ping_ms'] as num?)?.toDouble(),
      loadedPingMs: (row['loaded_ping_ms'] as num?)?.toDouble(),
      bufferbloatDeltaMs: (row['bufferbloat_delta_ms'] as num?)?.toDouble(),
      samples: sampleList,
      rawJson: row['raw_json'] as String? ?? '',
      status: row['status'] as String,
      errorMessage: row['error_message'] as String?,
    );
  }

  void dispose() {
    _db?.close();
    _db = null;
  }
}
