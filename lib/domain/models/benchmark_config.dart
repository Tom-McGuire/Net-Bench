import 'network_validator.dart';

class BenchmarkConfig {
  const BenchmarkConfig({
    this.targetHost = '127.0.0.1',
    this.port = 5201,
    this.protocol = 'tcp',
    this.direction = 'upload',
    this.streams = 1,
    this.durationSeconds = 10,
    this.udpBandwidthMbps = 100,
    this.socketBufferSizeKb,
    this.intervalSeconds = 1.0,
    this.profileName = 'Custom Benchmark',
    this.isDemoMode = false,
    this.bindAddress,
  });

  final String targetHost;
  final int port;
  final String protocol; // 'tcp' | 'udp'
  final String direction; // 'upload' | 'download' | 'bidirectional'
  final int streams;
  final int durationSeconds;
  final int udpBandwidthMbps;
  final int? socketBufferSizeKb;
  final double intervalSeconds;
  final String profileName;
  final bool isDemoMode;
  final String? bindAddress;

  bool get isUdp => protocol.toLowerCase() == 'udp';
  bool get isReverse => direction.toLowerCase() == 'download';
  bool get isBidirectional => direction.toLowerCase() == 'bidirectional';

  bool get isValid =>
      NetworkValidator.isValidHost(targetHost) &&
      NetworkValidator.isValidPort(port) &&
      (bindAddress == null ||
          bindAddress!.isEmpty ||
          bindAddress == '0.0.0.0' ||
          NetworkValidator.isValidHost(bindAddress));

  BenchmarkConfig copyWith({
    String? targetHost,
    int? port,
    String? protocol,
    String? direction,
    int? streams,
    int? durationSeconds,
    int? udpBandwidthMbps,
    int? socketBufferSizeKb,
    double? intervalSeconds,
    String? profileName,
    bool? isDemoMode,
    String? bindAddress,
  }) {
    return BenchmarkConfig(
      targetHost: targetHost ?? this.targetHost,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      direction: direction ?? this.direction,
      streams: streams ?? this.streams,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      udpBandwidthMbps: udpBandwidthMbps ?? this.udpBandwidthMbps,
      socketBufferSizeKb: socketBufferSizeKb ?? this.socketBufferSizeKb,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      profileName: profileName ?? this.profileName,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      bindAddress: bindAddress ?? this.bindAddress,
    );
  }

  /// Builds the CLI argument array for running iperf3.
  /// Single source of truth for both execution and command preview.
  List<String> toCliArguments({
    bool useJsonStream = false,
    bool forceFlush = true,
  }) {
    final args = <String>[
      '-c', targetHost,
      '-p', port.toString(),
      '-t', durationSeconds.toString(),
      '-i', intervalSeconds.toString(),
      '-P', streams.toString(),
    ];

    if (bindAddress != null &&
        bindAddress!.trim().isNotEmpty &&
        bindAddress != '0.0.0.0') {
      args.addAll(['-B', bindAddress!.trim()]);
    }

    if (forceFlush) {
      args.add('--forceflush');
    }

    if (useJsonStream) {
      args.add('--json-stream');
    }

    if (isUdp) {
      args.add('-u');
      args.addAll(['-b', '${udpBandwidthMbps}M']);
    }

    if (isReverse) {
      args.add('-R');
    } else if (isBidirectional) {
      args.add('--bidir');
    }

    if (socketBufferSizeKb != null && socketBufferSizeKb! > 0) {
      args.addAll(['-w', '${socketBufferSizeKb}K']);
    }

    return args;
  }

  /// Returns user-friendly CLI command preview string matching exact execution.
  String toCliCommandString(String binaryPath, {bool useJsonStream = false}) {
    final escapedPath = binaryPath.contains(' ') ? '"$binaryPath"' : binaryPath;
    final args = toCliArguments(useJsonStream: useJsonStream);
    return '$escapedPath ${args.join(' ')}';
  }

  Map<String, dynamic> toMap() => {
        'targetHost': targetHost,
        'port': port,
        'protocol': protocol,
        'direction': direction,
        'streams': streams,
        'durationSeconds': durationSeconds,
        'udpBandwidthMbps': udpBandwidthMbps,
        'socketBufferSizeKb': socketBufferSizeKb,
        'intervalSeconds': intervalSeconds,
        'profileName': profileName,
        'isDemoMode': isDemoMode,
        'bindAddress': bindAddress,
      };

  factory BenchmarkConfig.fromMap(Map<String, dynamic> map) => BenchmarkConfig(
        targetHost: map['targetHost'] as String? ?? '127.0.0.1',
        port: map['port'] as int? ?? 5201,
        protocol: map['protocol'] as String? ?? 'tcp',
        direction: map['direction'] as String? ?? 'upload',
        streams: map['streams'] as int? ?? 1,
        durationSeconds: map['durationSeconds'] as int? ?? 10,
        udpBandwidthMbps: map['udpBandwidthMbps'] as int? ?? 100,
        socketBufferSizeKb: map['socketBufferSizeKb'] as int?,
        intervalSeconds: (map['intervalSeconds'] as num?)?.toDouble() ?? 1.0,
        profileName: map['profileName'] as String? ?? 'Custom Benchmark',
        isDemoMode: map['isDemoMode'] as bool? ?? false,
        bindAddress: map['bindAddress'] as String?,
      );
}
