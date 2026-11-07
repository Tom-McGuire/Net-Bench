import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:net_bench/data/repositories/benchmark_repository.dart';
import 'package:net_bench/data/services/database/benchmark_database_service.dart';
import 'package:net_bench/domain/models/benchmark_preset.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/discovered_node.dart';
import 'package:net_bench/ui/view_models/benchmark_view_model.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';

void main() {
  late Database inMemoryDb;
  late BenchmarkDatabaseService dbService;
  late BenchmarkRepository repository;

  setUp(() async {
    inMemoryDb = sqlite3.openInMemory();
    dbService = BenchmarkDatabaseService(db: inMemoryDb);
    repository = BenchmarkRepository(dbService: dbService);
    await repository.init();
  });

  tearDown(() {
    repository.dispose();
  });

  group('BenchmarkViewModel Tests', () {
    test('initializes with default preset and valid configuration', () async {
      final vm = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm.selectedPreset, isNotNull);
      expect(vm.config.targetHost, equals('127.0.0.1'));
      expect(vm.config.port, equals(5201));
      expect(vm.isRunning, isFalse);
      expect(vm.searchQuery, isEmpty);
      expect(vm.protocolFilter, equals('ALL'));
      expect(vm.validationError, isNull);

      vm.dispose();
    });

    test('selectPreset updates configuration while preserving host and port', () async {
      final vm = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      vm.setTargetHost('10.0.0.99');
      vm.setPort(5209);

      final udpPreset = BenchmarkPreset.defaultPresets
          .firstWhere((p) => p.config.protocol == 'udp');
      vm.selectPreset(udpPreset);

      expect(vm.selectedPreset?.id, equals(udpPreset.id));
      expect(vm.config.protocol, equals('udp'));
      expect(vm.config.targetHost, equals('10.0.0.99'));
      expect(vm.config.port, equals(5209));

      vm.dispose();
    });

    test('configuration setters update properties and trigger notification', () async {
      final vm = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      vm.setTargetHost('192.168.1.1');
      expect(vm.config.targetHost, equals('192.168.1.1'));

      vm.setPort(9000);
      expect(vm.config.port, equals(9000));

      vm.setStreams(16);
      expect(vm.config.streams, equals(16));

      vm.setDuration(25);
      expect(vm.config.durationSeconds, equals(25));

      vm.setDirection('download');
      expect(vm.config.direction, equals('download'));

      vm.setProtocol('udp');
      expect(vm.config.protocol, equals('udp'));

      vm.setDemoMode(true);
      expect(vm.isDemoMode, isTrue);

      vm.setBindAddress('192.168.1.50');
      expect(vm.config.bindAddress, equals('192.168.1.50'));

      vm.setBindAddress('0.0.0.0');
      expect(vm.config.bindAddress, isNull);

      vm.dispose();
    });

    test('startBenchmark rejects invalid host or port with descriptive validation error', () async {
      final vm = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      // Test invalid hostname/IP
      vm.setTargetHost('invalid host with spaces; rm -rf');
      vm.startBenchmark();
      expect(vm.isRunning, isFalse);
      expect(vm.validationError, equals('Invalid target host or IP address format.'));

      // Test invalid port
      vm.setTargetHost('127.0.0.1');
      vm.setPort(99999);
      vm.startBenchmark();
      expect(vm.isRunning, isFalse);
      expect(vm.validationError, equals('Port must be between 1 and 65535.'));

      vm.dispose();
    });

    test('startBenchmark runs mock benchmark and calculates live throughput metrics', () async {
      final vm = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      vm.setTargetHost('127.0.0.1');
      vm.setPort(5201);
      vm.setDemoMode(true);
      vm.setDuration(2);

      expect(vm.instantThroughputMbps, equals(0.0));
      expect(vm.peakThroughputMbps, equals(0.0));
      expect(vm.avgThroughputMbps, equals(0.0));

      vm.startBenchmark();
      expect(vm.isRunning, isTrue);
      expect(vm.validationError, isNull);

      // Wait for at least one sample to stream in
      await Future.delayed(const Duration(milliseconds: 1100));

      expect(vm.liveSamples, isNotEmpty);
      expect(vm.instantThroughputMbps, greaterThan(0.0));
      expect(vm.peakThroughputMbps, greaterThan(0.0));
      expect(vm.avgThroughputMbps, greaterThan(0.0));

      // Cancel early to avoid long waiting
      vm.stopBenchmark();
      expect(vm.isRunning, isFalse);

      vm.dispose();
    });

    test('selectDiscoveredNode populates target host and port', () async {
      final vm = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      final node = DiscoveredNode(
        ip: '192.168.1.200',
        hostname: 'iperf-server-box',
        port: 5205,
        discoveryType: 'peer_beacon',
        lastSeen: DateTime.now(),
      );

      vm.selectDiscoveredNode(node);
      expect(vm.config.targetHost, equals('192.168.1.200'));
      expect(vm.config.port, equals(5205));

      vm.dispose();
    });

    test('historical runs filtering, search, and deletion', () async {
      final vm = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      final run1 = BenchmarkResult(
        id: 'run-1',
        timestamp: DateTime(2026, 11, 1),
        profileName: 'Office Router Test',
        targetHost: '192.168.1.1',
        port: 5201,
        protocol: 'tcp',
        direction: 'upload',
        streams: 1,
        durationSeconds: 10,
        avgThroughputMbps: 940.0,
        peakThroughputMbps: 950.0,
        minThroughputMbps: 900.0,
        totalBytes: 1000,
        retransmits: 0,
      );

      final run2 = BenchmarkResult(
        id: 'run-2',
        timestamp: DateTime(2026, 11, 2),
        profileName: 'UDP Jitter Check',
        targetHost: '10.0.0.50',
        port: 5201,
        protocol: 'udp',
        direction: 'download',
        streams: 1,
        durationSeconds: 5,
        avgThroughputMbps: 100.0,
        peakThroughputMbps: 105.0,
        minThroughputMbps: 95.0,
        totalBytes: 500,
        retransmits: 0,
      );

      dbService.saveResult(run1);
      dbService.saveResult(run2);

      // Reload history
      vm.clearFilters();
      expect(vm.historicalRuns.length, equals(2));

      // Filter by search query
      vm.setSearchQuery('Router');
      expect(vm.historicalRuns.length, equals(1));
      expect(vm.historicalRuns.first.id, equals('run-1'));

      // Filter by protocol
      vm.clearFilters();
      vm.setProtocolFilter('UDP');
      expect(vm.historicalRuns.length, equals(1));
      expect(vm.historicalRuns.first.id, equals('run-2'));

      // Inspector and selection
      vm.clearFilters();
      vm.selectInspectorRecord(run1);
      expect(vm.selectedInspectorRecord?.id, equals('run-1'));

      vm.setInspectorTabIndex(2);
      expect(vm.inspectorTabIndex, equals(2));

      // Comparison toggling
      vm.toggleComparisonSelection('run-1');
      vm.toggleComparisonSelection('run-2');
      expect(vm.selectedComparisonIds.contains('run-1'), isTrue);
      expect(vm.selectedComparisonIds.contains('run-2'), isTrue);
      expect(vm.comparisonRuns.length, equals(2));

      vm.toggleComparisonSelection('run-1');
      expect(vm.selectedComparisonIds.contains('run-1'), isFalse);
      expect(vm.comparisonRuns.length, equals(1));

      vm.clearComparisonSelection();
      expect(vm.selectedComparisonIds, isEmpty);

      // Deletion of a run
      vm.deleteHistoricalRun('run-1');
      expect(vm.historicalRuns.any((r) => r.id == 'run-1'), isFalse);

      // Clear all history
      vm.clearAllHistory();
      expect(vm.historicalRuns, isEmpty);

      vm.dispose();
    });
  });

  group('ServerViewModel Tests', () {
    test('updates port, bind address, and oneOff settings', () async {
      final vm = ServerViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm.port, equals(5201));
      expect(vm.bindAddress, equals('0.0.0.0'));
      expect(vm.oneOff, isFalse);

      vm.setPort(5205);
      expect(vm.port, equals(5205));

      vm.setBindAddress('127.0.0.1');
      expect(vm.bindAddress, equals('127.0.0.1'));

      vm.setOneOff(true);
      expect(vm.oneOff, isTrue);

      vm.dispose();
    });

    test('toggleServer cleanly starts and stops simulated daemon', () async {
      final vm = ServerViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm.isRunning, isFalse);

      // Start simulated server
      final started = await vm.toggleServer(forceDemo: true);
      expect(started, isTrue);
      expect(vm.isRunning, isTrue);
      expect(vm.isSimulated, isTrue);

      // Stop simulated server via toggle
      final stopped = await vm.toggleServer();
      expect(stopped, isTrue);
      expect(vm.isRunning, isFalse);

      // Test stopServer method directly
      await vm.toggleServer(forceDemo: true);
      expect(vm.isRunning, isTrue);
      await vm.stopServer();
      expect(vm.isRunning, isFalse);

      vm.dispose();
    });
  });
}
