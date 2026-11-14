import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:net_bench/data/repositories/benchmark_repository.dart';
import 'package:net_bench/data/services/database/benchmark_database_service.dart';
import 'package:net_bench/domain/models/launch_adapter_config.dart';
import 'package:net_bench/domain/models/network_adapter.dart';
import 'package:net_bench/ui/view_models/benchmark_view_model.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';

class _FakeAdapterRepository extends BenchmarkRepository {
  _FakeAdapterRepository({
    required super.dbService,
    required this.adapters,
  });

  List<NetworkAdapter> adapters;

  @override
  Future<List<NetworkAdapter>> getNetworkAdapters() async => adapters;
}

void main() {
  group('LaunchAdapterConfig.fromArgs', () {
    test('parses space-separated flags', () {
      final config = LaunchAdapterConfig.fromArgs([
        '--adapter-ip',
        '192.168.1.50',
        '--adapter-name',
        'eth0',
      ]);

      expect(config.hasOverride, isTrue);
      expect(config.adapterIp, equals('192.168.1.50'));
      expect(config.adapterName, equals('eth0'));
    });

    test('parses equals-separated flags and trims whitespace', () {
      final config = LaunchAdapterConfig.fromArgs([
        '--adapter-ip= 10.0.0.42 ',
        '--adapter-name=en0',
      ]);

      expect(config.hasOverride, isTrue);
      expect(config.adapterIp, equals('10.0.0.42'));
      expect(config.adapterName, equals('en0'));
    });

    test('ignores unrelated args and handles missing/empty values', () {
      final empty = LaunchAdapterConfig.fromArgs(['--verbose', '--port', '5201']);
      expect(empty.hasOverride, isFalse);
      expect(empty.adapterIp, isNull);
      expect(empty.adapterName, isNull);

      final blank = LaunchAdapterConfig.fromArgs([
        '--adapter-ip=',
        '--adapter-name',
        '',
      ]);
      expect(blank.hasOverride, isFalse);

      final dangling = LaunchAdapterConfig.fromArgs(['--adapter-ip']);
      expect(dangling.hasOverride, isFalse);
    });
  });

  group('LaunchAdapterConfig.matchAdapter', () {
    const adapters = [
      NetworkAdapter(name: 'Auto / Default Route', ipAddress: '0.0.0.0'),
      NetworkAdapter(name: 'eth0', ipAddress: '192.168.1.50'),
      NetworkAdapter(name: 'wlan0-office', ipAddress: '10.0.0.42'),
      NetworkAdapter(name: 'Loopback', ipAddress: '127.0.0.1', isLoopback: true),
    ];

    test('Priority 1: matches exact IPv4 address over name', () {
      const config = LaunchAdapterConfig(
        adapterIp: '10.0.0.42',
        adapterName: 'eth0',
      );
      final matched = config.matchAdapter(adapters);
      expect(matched?.ipAddress, equals('10.0.0.42'));
    });

    test('Priority 2: falls back to exact case-insensitive name match', () {
      const config = LaunchAdapterConfig(
        adapterIp: '172.16.0.99',
        adapterName: 'ETH0',
      );
      final matched = config.matchAdapter(adapters);
      expect(matched?.ipAddress, equals('192.168.1.50'));
    });

    test('Priority 2: falls back to substring case-insensitive name match', () {
      const config = LaunchAdapterConfig(
        adapterName: 'OFFICE',
      );
      final matched = config.matchAdapter(adapters);
      expect(matched?.ipAddress, equals('10.0.0.42'));
    });

    test('Priority 3: returns null when neither IP nor name matches', () {
      const config = LaunchAdapterConfig(
        adapterIp: '172.16.0.99',
        adapterName: 'nonexistent',
      );
      expect(config.matchAdapter(adapters), isNull);
    });
  });

  group('ViewModel Startup Adapter Pre-Selection', () {
    late Database db;
    late _FakeAdapterRepository repository;

    setUp(() {
      db = sqlite3.openInMemory();
      repository = _FakeAdapterRepository(
        dbService: BenchmarkDatabaseService(db: db),
        adapters: const [
          NetworkAdapter(name: 'All Interfaces', ipAddress: '0.0.0.0'),
          NetworkAdapter(name: 'eth0', ipAddress: '192.168.1.50'),
          NetworkAdapter(name: 'wlan0', ipAddress: '10.0.0.42'),
        ],
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('BenchmarkViewModel pre-selects matching adapter once and respects manual changes', () async {
      final vm = BenchmarkViewModel(
        repository: repository,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterIp: '10.0.0.42',
          adapterName: 'wlan0',
        ),
      );

      // Wait for _init() + loadAdapters()
      await Future.delayed(const Duration(milliseconds: 50));

      expect(vm.config.bindAddress, equals('10.0.0.42'));

      // User manually switches adapter
      vm.setBindAddress('192.168.1.50');
      expect(vm.config.bindAddress, equals('192.168.1.50'));

      // Subsequent refresh must NOT override manual selection
      await vm.loadAdapters();
      expect(vm.config.bindAddress, equals('192.168.1.50'));

      vm.dispose();
    });

    test('ServerViewModel pre-selects matching adapter once and respects manual changes', () async {
      final serverVm = ServerViewModel(
        repository: repository,
        initialAdapterConfig: const LaunchAdapterConfig(
          adapterName: 'eth0',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(serverVm.bindAddress, equals('192.168.1.50'));

      // User manually switches adapter
      serverVm.setBindAddress('0.0.0.0');
      expect(serverVm.bindAddress, equals('0.0.0.0'));

      // Subsequent refresh must NOT override manual selection
      await serverVm.loadAdapters();
      expect(serverVm.bindAddress, equals('0.0.0.0'));

      serverVm.dispose();
    });
  });
}
