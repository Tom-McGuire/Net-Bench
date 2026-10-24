import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:net_bench/data/services/database/benchmark_database_service.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/live_sample.dart';

void main() {
  late BenchmarkDatabaseService dbService;

  setUp(() {
    final db = sqlite3.openInMemory();
    dbService = BenchmarkDatabaseService(db: db);
  });

  tearDown(() {
    dbService.dispose();
  });

  test('Save and query benchmark results', () {
    final res1 = BenchmarkResult(
      id: 'run_1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      profileName: '1G Full-Duplex',
      targetHost: '192.168.1.100',
      port: 5201,
      protocol: 'tcp',
      direction: 'upload',
      streams: 8,
      durationSeconds: 10,
      avgThroughputMbps: 940.5,
      peakThroughputMbps: 950.0,
      minThroughputMbps: 930.0,
      totalBytes: 1175625000,
      retransmits: 3,
      samples: [
        const LiveSample(
          interval: 1,
          secondsElapsed: 1.0,
          throughputMbps: 940.5,
        ),
      ],
      rawJson: '{"run":1}',
      status: 'completed',
    );

    final res2 = BenchmarkResult(
      id: 'run_2',
      timestamp: DateTime.now(),
      profileName: 'UDP Jitter Check',
      targetHost: '192.168.1.101',
      port: 5201,
      protocol: 'udp',
      direction: 'upload',
      streams: 1,
      durationSeconds: 10,
      avgThroughputMbps: 98.4,
      peakThroughputMbps: 99.1,
      minThroughputMbps: 97.2,
      totalBytes: 123000000,
      jitterMs: 0.24,
      lossPercent: 0.1,
      retransmits: 0,
      samples: [],
      rawJson: '{"run":2}',
      status: 'completed',
    );

    dbService.saveResult(res1);
    dbService.saveResult(res2);

    expect(dbService.getRunCount(), equals(2));

    // Retrieve all
    final all = dbService.getRuns();
    expect(all.length, equals(2));
    expect(all.first.id, equals('run_2')); // Most recent first

    // Protocol filter
    final tcpOnly = dbService.getRuns(protocol: 'TCP');
    expect(tcpOnly.length, equals(1));
    expect(tcpOnly.first.id, equals('run_1'));

    final udpOnly = dbService.getRuns(protocol: 'UDP');
    expect(udpOnly.length, equals(1));
    expect(udpOnly.first.id, equals('run_2'));

    // Search query
    final search = dbService.getRuns(searchQuery: '100');
    expect(search.length, equals(1));
    expect(search.first.targetHost, equals('192.168.1.100'));

    // Delete
    dbService.deleteRun('run_1');
    expect(dbService.getRunCount(), equals(1));
    expect(dbService.getRunById('run_1'), isNull);

    // Clear all
    dbService.clearAllRuns();
    expect(dbService.getRunCount(), equals(0));
  });
}
