import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/services/discovery/discovery_service.dart';
import 'package:net_bench/domain/models/discovered_node.dart';

void main() {
  group('DiscoveredNode Model Tests', () {
    test('displayName formats correctly depending on hostname and IP', () {
      final nodeWithHost = DiscoveredNode(
        ip: '192.168.1.50',
        hostname: 'nas-server',
        port: 5201,
        discoveryType: 'peer_beacon',
        lastSeen: DateTime(2026, 11, 6),
      );
      expect(nodeWithHost.displayName, equals('nas-server (192.168.1.50)'));

      final nodeWithoutHost = DiscoveredNode(
        ip: '192.168.1.50',
        hostname: '',
        port: 5201,
        discoveryType: 'tcp_sweep',
        lastSeen: DateTime(2026, 11, 6),
      );
      expect(nodeWithoutHost.displayName, equals('192.168.1.50'));

      final nodeSameHostAsIp = DiscoveredNode(
        ip: '192.168.1.50',
        hostname: '192.168.1.50',
        port: 5201,
        discoveryType: 'peer_beacon',
        lastSeen: DateTime(2026, 11, 6),
      );
      expect(nodeSameHostAsIp.displayName, equals('192.168.1.50'));
    });

    test('toMap and fromMap perform round-trip serialization accurately', () {
      final now = DateTime(2026, 11, 6, 12, 0, 0);
      final node = DiscoveredNode(
        ip: '10.0.0.25',
        hostname: 'edge-router',
        port: 5202,
        discoveryType: 'peer_beacon',
        latencyMs: 3,
        lastSeen: now,
      );

      final map = node.toMap();
      expect(map['ip'], equals('10.0.0.25'));
      expect(map['hostname'], equals('edge-router'));
      expect(map['port'], equals(5202));
      expect(map['discoveryType'], equals('peer_beacon'));
      expect(map['latencyMs'], equals(3));
      expect(map['lastSeen'], equals(now.toIso8601String()));

      final restored = DiscoveredNode.fromMap(map);
      expect(restored.ip, equals(node.ip));
      expect(restored.hostname, equals(node.hostname));
      expect(restored.port, equals(node.port));
      expect(restored.discoveryType, equals(node.discoveryType));
      expect(restored.latencyMs, equals(node.latencyMs));
      expect(restored.lastSeen.isAtSameMomentAs(now), isTrue);
    });

    test('fromMap handles missing or null optional fields with safe defaults', () {
      final minimalMap = {
        'ip': '172.16.0.10',
      };

      final restored = DiscoveredNode.fromMap(minimalMap);
      expect(restored.ip, equals('172.16.0.10'));
      expect(restored.hostname, equals(''));
      expect(restored.port, equals(5201));
      expect(restored.discoveryType, equals('tcp_sweep'));
      expect(restored.latencyMs, isNull);
      expect(restored.lastSeen, isNotNull);
    });
  });

  group('DiscoveryService Lifecycle Tests', () {
    late DiscoveryService discoveryService;

    setUp(() {
      discoveryService = DiscoveryService();
    });

    tearDown(() {
      discoveryService.dispose();
    });

    test('initial state has empty currentNodes and not scanning', () {
      expect(discoveryService.currentNodes, isEmpty);
      expect(discoveryService.isScanning, isFalse);
    });

    test('stop and dispose can be invoked multiple times cleanly without throwing', () {
      discoveryService.stop();
      discoveryService.dispose();
      // calling again should be safe
      discoveryService.stop();
      discoveryService.dispose();
    });

    test('scanSubnet runs safely without crashing', () async {
      // Subnet scan across local interfaces (if any) or returns empty list
      final nodes = await discoveryService.scanSubnet(port: 99999); // invalid port normalized to 5201
      expect(nodes, isA<List<DiscoveredNode>>());
      expect(discoveryService.isScanning, isFalse);
    });
  });
}
