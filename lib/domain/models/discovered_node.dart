class DiscoveredNode {
  const DiscoveredNode({
    required this.ip,
    required this.hostname,
    required this.port,
    required this.discoveryType, // 'tcp_sweep' | 'peer_beacon' | 'manual'
    this.latencyMs,
    required this.lastSeen,
  });

  final String ip;
  final String hostname;
  final int port;
  final String discoveryType;
  final int? latencyMs;
  final DateTime lastSeen;

  String get displayName =>
      hostname.isNotEmpty && hostname != ip ? '$hostname ($ip)' : ip;

  Map<String, dynamic> toMap() => {
        'ip': ip,
        'hostname': hostname,
        'port': port,
        'discoveryType': discoveryType,
        'latencyMs': latencyMs,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory DiscoveredNode.fromMap(Map<String, dynamic> map) => DiscoveredNode(
        ip: map['ip'] as String,
        hostname: map['hostname'] as String? ?? '',
        port: map['port'] as int? ?? 5201,
        discoveryType: map['discoveryType'] as String? ?? 'tcp_sweep',
        latencyMs: map['latencyMs'] as int?,
        lastSeen: DateTime.tryParse(map['lastSeen'] as String? ?? '') ??
            DateTime.now(),
      );
}
