import 'dart:io';
import '../../../domain/models/network_adapter.dart';

typedef RawInterfaceInfo = ({String name, List<String> addresses});
typedef SystemInterfaceProvider = Future<List<RawInterfaceInfo>> Function();

class NetworkInterfaceService {
  NetworkInterfaceService({SystemInterfaceProvider? interfaceProvider})
      : _interfaceProvider = interfaceProvider ?? _defaultInterfaceProvider;

  final SystemInterfaceProvider _interfaceProvider;

  static Future<List<RawInterfaceInfo>> _defaultInterfaceProvider() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: true,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    return interfaces.map((i) {
      return (
        name: i.name,
        addresses: i.addresses.map((a) => a.address).toList(),
      );
    }).toList();
  }

  /// Queries system network interfaces and returns available adapters for binding.
  /// Always includes '0.0.0.0' (All Interfaces) and '127.0.0.1' (Loopback).
  Future<List<NetworkAdapter>> getAvailableAdapters() async {
    final adapters = <NetworkAdapter>[
      const NetworkAdapter(
        name: 'All Interfaces',
        ipAddress: '0.0.0.0',
      ),
      const NetworkAdapter(
        name: 'Loopback',
        ipAddress: '127.0.0.1',
        isLoopback: true,
      ),
    ];

    try {
      final interfaces = await _interfaceProvider();

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.trim();
          if (ip.isEmpty) continue;
          if (ip == '127.0.0.1' || ip == '0.0.0.0') continue;

          // Avoid duplicates
          if (!adapters.any((a) => a.ipAddress == ip)) {
            adapters.add(NetworkAdapter(
              name: iface.name,
              ipAddress: ip,
            ));
          }
        }
      }
    } catch (_) {}

    return adapters;
  }
}
