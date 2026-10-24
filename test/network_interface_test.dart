import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/services/network/network_interface_service.dart';
import 'package:net_bench/domain/models/benchmark_config.dart';
import 'package:net_bench/domain/models/network_adapter.dart';

void main() {
  group('NetworkAdapter Model', () {
    test('displayName formats standard and custom adapters', () {
      const all = NetworkAdapter(name: 'All Interfaces', ipAddress: '0.0.0.0');
      expect(all.displayName, equals('All Interfaces (0.0.0.0)'));

      const loop = NetworkAdapter(name: 'Loopback', ipAddress: '127.0.0.1', isLoopback: true);
      expect(loop.displayName, equals('Loopback (127.0.0.1)'));

      const wifi = NetworkAdapter(name: 'Wi-Fi', ipAddress: '10.101.1.27');
      expect(wifi.displayName, equals('Wi-Fi (10.101.1.27)'));
    });

    test('equality and hashCode are based on ipAddress', () {
      const a1 = NetworkAdapter(name: 'Wi-Fi', ipAddress: '192.168.1.50');
      const a2 = NetworkAdapter(name: 'Wireless', ipAddress: '192.168.1.50');
      const a3 = NetworkAdapter(name: 'Ethernet', ipAddress: '192.168.1.51');

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1, isNot(equals(a3)));
    });
  });

  group('NetworkInterfaceService', () {
    test('always provides All Interfaces and Loopback even with empty interfaces', () async {
      final service = NetworkInterfaceService(
        interfaceProvider: () async => <RawInterfaceInfo>[],
      );

      final adapters = await service.getAvailableAdapters();
      expect(adapters.length, equals(2));
      expect(adapters[0].ipAddress, equals('0.0.0.0'));
      expect(adapters[1].ipAddress, equals('127.0.0.1'));
    });

    test('extracts and aggregates active IPv4 interfaces', () async {
      final mockInterfaces = <RawInterfaceInfo>[
        (name: 'Wi-Fi', addresses: ['10.101.1.27']),
        (name: 'Tailscale', addresses: ['100.85.170.111']),
        (name: 'Loopback Pseudo-Interface', addresses: ['127.0.0.1']),
      ];

      final service = NetworkInterfaceService(
        interfaceProvider: () async => mockInterfaces,
      );

      final adapters = await service.getAvailableAdapters();
      expect(adapters.length, equals(4)); // 0.0.0.0, 127.0.0.1, Wi-Fi, Tailscale
      expect(adapters.any((a) => a.name == 'Wi-Fi' && a.ipAddress == '10.101.1.27'), isTrue);
      expect(adapters.any((a) => a.name == 'Tailscale' && a.ipAddress == '100.85.170.111'), isTrue);
    });
  });

  group('BenchmarkConfig Bind Adapter CLI Generation', () {
    test('appends -B flag when bindAddress is set to a specific IP', () {
      const config = BenchmarkConfig(
        targetHost: '192.168.1.1',
        port: 5201,
        bindAddress: '10.101.1.27',
      );

      final args = config.toCliArguments();
      expect(args, contains('-B'));
      expect(args[args.indexOf('-B') + 1], equals('10.101.1.27'));

      final cmd = config.toCliCommandString('iperf3');
      expect(cmd, contains('-B 10.101.1.27'));
    });

    test('omits -B flag when bindAddress is null, empty, or 0.0.0.0', () {
      const configNull = BenchmarkConfig(
        targetHost: '192.168.1.1',
        port: 5201,
      );
      expect(configNull.toCliArguments(), isNot(contains('-B')));

      const configZero = BenchmarkConfig(
        targetHost: '192.168.1.1',
        port: 5201,
        bindAddress: '0.0.0.0',
      );
      expect(configZero.toCliArguments(), isNot(contains('-B')));
    });
  });
}
