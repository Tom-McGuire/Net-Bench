import 'network_adapter.dart';

/// Parsed startup network adapter preference passed via CLI arguments
/// (`--adapter-ip`, `--adapter-name`) from Net-App-Launcher or scripts.
class LaunchAdapterConfig {
  final String? adapterIp;
  final String? adapterName;

  const LaunchAdapterConfig({this.adapterIp, this.adapterName});

  bool get hasOverride =>
      (adapterIp != null && adapterIp!.isNotEmpty) ||
      (adapterName != null && adapterName!.isNotEmpty);

  factory LaunchAdapterConfig.fromArgs(List<String> args) {
    String? ip;
    String? name;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--adapter-ip' && i + 1 < args.length) {
        ip = args[i + 1].trim();
        i++;
      } else if (arg.startsWith('--adapter-ip=')) {
        ip = arg.substring('--adapter-ip='.length).trim();
      } else if (arg == '--adapter-name' && i + 1 < args.length) {
        name = args[i + 1].trim();
        i++;
      } else if (arg.startsWith('--adapter-name=')) {
        name = arg.substring('--adapter-name='.length).trim();
      }
    }
    return LaunchAdapterConfig(adapterIp: ip, adapterName: name);
  }

  /// Resolves the best matching [NetworkAdapter] from [adapters] using the
  /// suite priority order:
  /// 1. Exact IPv4 address match on [adapterIp].
  /// 2. Exact case-insensitive name match, then substring case-insensitive
  ///    match on [adapterName] (excluding the `0.0.0.0` wildcard entry).
  /// 3. `null` if no match is found (caller falls back to default).
  NetworkAdapter? matchAdapter(List<NetworkAdapter> adapters) {
    if (!hasOverride || adapters.isEmpty) return null;

    final targetIp = adapterIp?.trim();
    if (targetIp != null && targetIp.isNotEmpty) {
      for (final adapter in adapters) {
        if (adapter.ipAddress == targetIp) {
          return adapter;
        }
      }
    }

    final targetName = adapterName?.trim().toLowerCase();
    if (targetName != null && targetName.isNotEmpty) {
      final candidates = adapters.where((a) => a.ipAddress != '0.0.0.0');
      for (final adapter in candidates) {
        if (adapter.name.toLowerCase() == targetName) {
          return adapter;
        }
      }
      for (final adapter in candidates) {
        if (adapter.name.toLowerCase().contains(targetName)) {
          return adapter;
        }
      }
    }

    return null;
  }
}
