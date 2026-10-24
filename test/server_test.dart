import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/repositories/benchmark_repository.dart';
import 'package:net_bench/data/services/iperf/iperf_server_service.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';

void main() {
  group('IPerfServerService Simulated & Fallback Mode', () {
    test('startSimulatedServer starts cleanly and emits listening state', () async {
      final service = IPerfServerService();
      expect(service.currentState.isRunning, isFalse);

      final success = await service.startSimulatedServer(
        port: 5201,
        bindAddress: '127.0.0.1',
      );

      expect(success, isTrue);
      expect(service.currentState.isRunning, isTrue);
      expect(service.currentState.isSimulated, isTrue);
      expect(service.currentState.port, equals(5201));
      expect(service.currentState.boundAddress, equals('127.0.0.1'));
      expect(service.currentState.logs.any((l) => l.contains('SIMULATED SERVER STARTED')), isTrue);

      await service.stopServer();
      expect(service.currentState.isRunning, isFalse);
    });

    test('BenchmarkRepository falls back to simulated server when binary is unavailable', () async {
      final repo = BenchmarkRepository();
      // Binary is not available by default before discovery or when missing
      expect(repo.binaryInfo.isAvailable, isFalse);

      final started = await repo.startServer(
        port: 5202,
        bindAddress: '127.0.0.1',
      );

      expect(started, isTrue);
      expect(repo.currentServerState.isRunning, isTrue);
      expect(repo.currentServerState.isSimulated, isTrue);
      expect(repo.currentServerState.port, equals(5202));

      await repo.stopServer();
      expect(repo.currentServerState.isRunning, isFalse);
    });

    test('ServerViewModel toggleServer toggles server on and off cleanly', () async {
      final repo = BenchmarkRepository();
      final vm = ServerViewModel(repository: repo);

      expect(vm.isRunning, isFalse);

      // Start server
      final started = await vm.toggleServer();
      expect(started, isTrue);
      expect(vm.isRunning, isTrue);

      // Stop server
      final stopped = await vm.toggleServer();
      expect(stopped, isTrue);
      expect(vm.isRunning, isFalse);

      vm.dispose();
      repo.dispose();
    });
  });
}
