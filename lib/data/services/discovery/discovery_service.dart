import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../domain/models/discovered_node.dart';
import '../../../domain/models/network_validator.dart';

class DiscoveryService {
  final Map<String, DiscoveredNode> _nodes = {};
  final StreamController<List<DiscoveredNode>> _nodesController =
      StreamController<List<DiscoveredNode>>.broadcast();

  RawDatagramSocket? _broadcastSocket;
  Timer? _beaconTimer;
  Timer? _evictionTimer;
  bool _isScanning = false;

  bool get isScanning => _isScanning;
  List<DiscoveredNode> get currentNodes => _nodes.values.toList();
  Stream<List<DiscoveredNode>> get nodesStream => _nodesController.stream;

  static const int beaconPort = 52010;
  static const int maxDiscoveredNodes = 100;
  static const int nodeTtlSeconds = 60;

  /// Starts listening for peer UDP announcements and broadcasting local presence.
  Future<void> startPeerDiscovery({
    required String localHostname,
    required int iperfPort,
    required bool isServerRunning,
  }) async {
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
        reusePort: false,
      );
      _broadcastSocket!.broadcastEnabled = true;

      _broadcastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _broadcastSocket?.receive();
          if (dg != null) {
            _handlePeerDatagram(dg);
          }
        }
      });

      // Periodically broadcast presence
      _beaconTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _broadcastPresence(localHostname, iperfPort, isServerRunning);
      });

      // Periodically evict stale nodes
      _evictionTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _evictStaleNodes();
      });
    } catch (_) {
      // Broadcast might be restricted or port occupied
    }
  }

  void _broadcastPresence(String hostname, int port, bool isServerRunning) {
    if (_broadcastSocket == null) return;
    try {
      final safeHostname = hostname
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
          .trim();
      final payload = jsonEncode({
        'app': 'net-bench',
        'hostname': safeHostname.length > 48
            ? safeHostname.substring(0, 48)
            : safeHostname,
        'port': port,
        'server_running': isServerRunning,
      });
      final bytes = utf8.encode(payload);
      _broadcastSocket?.send(
        bytes,
        InternetAddress('255.255.255.255'),
        beaconPort,
      );
    } catch (_) {}
  }

  void _handlePeerDatagram(Datagram dg) {
    // Drop oversize datagrams to avoid memory bloat
    if (dg.data.length > 2048) return;

    try {
      final msg = utf8.decode(dg.data);
      final json = jsonDecode(msg);
      if (json is! Map<String, dynamic>) return;

      if (json['app'] == 'net-bench') {
        final ip = dg.address.address;
        if (!NetworkValidator.isValidIp(ip)) return;

        // Sanitize and bounds-check hostname
        String hostname = ip;
        if (json['hostname'] is String) {
          final rawHost = (json['hostname'] as String)
              .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
              .trim();
          if (rawHost.isNotEmpty) {
            hostname = rawHost.length > 48 ? rawHost.substring(0, 48) : rawHost;
          }
        }

        // Validate port
        int port = 5201;
        if (json['port'] is int && NetworkValidator.isValidPort(json['port'] as int)) {
          port = json['port'] as int;
        }

        _evictStaleNodes();

        // Enforce maximum capacity
        if (!_nodes.containsKey(ip) && _nodes.length >= maxDiscoveredNodes) {
          // Evict oldest node
          final oldestKey = _nodes.entries
              .reduce((a, b) => a.value.lastSeen.isBefore(b.value.lastSeen) ? a : b)
              .key;
          _nodes.remove(oldestKey);
        }

        _nodes[ip] = DiscoveredNode(
          ip: ip,
          hostname: hostname,
          port: port,
          discoveryType: 'peer_beacon',
          lastSeen: DateTime.now(),
        );
        _emitNodes();
      }
    } catch (_) {}
  }

  void _evictStaleNodes() {
    final now = DateTime.now();
    final toRemove = <String>[];
    for (final entry in _nodes.entries) {
      if (now.difference(entry.value.lastSeen).inSeconds > nodeTtlSeconds) {
        toRemove.add(entry.key);
      }
    }
    if (toRemove.isNotEmpty) {
      for (final key in toRemove) {
        _nodes.remove(key);
      }
      _emitNodes();
    }
  }

  /// Performs an asynchronous TCP sweep across the local /24 subnet for the given port.
  Future<List<DiscoveredNode>> scanSubnet({int port = 5201}) async {
    if (_isScanning) return currentNodes;
    if (!NetworkValidator.isValidPort(port)) port = 5201;

    _isScanning = true;

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final List<String> subnetIps = [];

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            // Scan 1 to 254
            for (int i = 1; i <= 254; i++) {
              final testIp = '$prefix.$i';
              if (testIp != addr.address) {
                subnetIps.add(testIp);
              }
            }
          }
        }
      }

      // Concurrently probe IPs in batches of 40
      const batchSize = 40;
      for (int i = 0; i < subnetIps.length; i += batchSize) {
        final end = (i + batchSize < subnetIps.length)
            ? i + batchSize
            : subnetIps.length;
        final batch = subnetIps.sublist(i, end);

        final futures = batch.map((ip) => _probeIp(ip, port));
        await Future.wait(futures);
      }
    } catch (_) {
    } finally {
      _isScanning = false;
      _emitNodes();
    }

    return currentNodes;
  }

  Future<void> _probeIp(String ip, int port) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 180),
      );
      sw.stop();
      socket.destroy();

      _evictStaleNodes();
      if (!_nodes.containsKey(ip) && _nodes.length >= maxDiscoveredNodes) {
        final oldestKey = _nodes.entries
            .reduce((a, b) => a.value.lastSeen.isBefore(b.value.lastSeen) ? a : b)
            .key;
        _nodes.remove(oldestKey);
      }

      _nodes[ip] = DiscoveredNode(
        ip: ip,
        hostname: '',
        port: port,
        discoveryType: 'tcp_sweep',
        latencyMs: sw.elapsedMilliseconds,
        lastSeen: DateTime.now(),
      );
      _emitNodes();
    } catch (_) {
      // Host not listening or timed out
    }
  }

  void _emitNodes() {
    if (!_nodesController.isClosed) {
      _nodesController.add(_nodes.values.toList());
    }
  }

  void stop() {
    _beaconTimer?.cancel();
    _evictionTimer?.cancel();
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  void dispose() {
    stop();
    _nodesController.close();
  }
}
