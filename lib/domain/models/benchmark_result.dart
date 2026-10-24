import 'dart:convert';
import 'live_sample.dart';

class BenchmarkResult {
  const BenchmarkResult({
    required this.id,
    required this.timestamp,
    required this.profileName,
    required this.targetHost,
    required this.port,
    required this.protocol,
    required this.direction,
    required this.streams,
    required this.durationSeconds,
    required this.avgThroughputMbps,
    required this.peakThroughputMbps,
    required this.minThroughputMbps,
    required this.totalBytes,
    this.jitterMs,
    this.lossPercent,
    this.lostPackets,
    this.totalPackets,
    this.retransmits = 0,
    this.baselinePingMs,
    this.loadedPingMs,
    this.bufferbloatDeltaMs,
    this.samples = const [],
    this.rawJson = '',
    this.status = 'completed',
    this.errorMessage,
  });

  final String id;
  final DateTime timestamp;
  final String profileName;
  final String targetHost;
  final int port;
  final String protocol;
  final String direction;
  final int streams;
  final int durationSeconds;
  final double avgThroughputMbps;
  final double peakThroughputMbps;
  final double minThroughputMbps;
  final int totalBytes;
  final double? jitterMs;
  final double? lossPercent;
  final int? lostPackets;
  final int? totalPackets;
  final int retransmits;
  final double? baselinePingMs;
  final double? loadedPingMs;
  final double? bufferbloatDeltaMs;
  final List<LiveSample> samples;
  final String rawJson;
  final String status;
  final String? errorMessage;

  bool get isSuccessful => status == 'completed';
  bool get isUdp => protocol.toLowerCase() == 'udp';

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'profileName': profileName,
        'targetHost': targetHost,
        'port': port,
        'protocol': protocol,
        'direction': direction,
        'streams': streams,
        'durationSeconds': durationSeconds,
        'avgThroughputMbps': avgThroughputMbps,
        'peakThroughputMbps': peakThroughputMbps,
        'minThroughputMbps': minThroughputMbps,
        'totalBytes': totalBytes,
        'jitterMs': jitterMs,
        'lossPercent': lossPercent,
        'lostPackets': lostPackets,
        'totalPackets': totalPackets,
        'retransmits': retransmits,
        'baselinePingMs': baselinePingMs,
        'loadedPingMs': loadedPingMs,
        'bufferbloatDeltaMs': bufferbloatDeltaMs,
        'samples': jsonEncode(samples.map((s) => s.toMap()).toList()),
        'rawJson': rawJson,
        'status': status,
        'errorMessage': errorMessage,
      };

  factory BenchmarkResult.fromMap(Map<String, dynamic> map) {
    List<LiveSample> sampleList = [];
    final samplesRaw = map['samples'];
    if (samplesRaw is String && samplesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(samplesRaw) as List<dynamic>;
        sampleList = decoded
            .map((item) => LiveSample.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    } else if (samplesRaw is List) {
      sampleList = samplesRaw
          .map((item) => LiveSample.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return BenchmarkResult(
      id: map['id']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      profileName: map['profileName'] as String? ?? 'Benchmark',
      targetHost: map['targetHost'] as String? ?? '127.0.0.1',
      port: (map['port'] as num?)?.toInt() ?? 5201,
      protocol: map['protocol'] as String? ?? 'tcp',
      direction: map['direction'] as String? ?? 'upload',
      streams: (map['streams'] as num?)?.toInt() ?? 1,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 10,
      avgThroughputMbps:
          (map['avgThroughputMbps'] as num?)?.toDouble() ?? 0.0,
      peakThroughputMbps:
          (map['peakThroughputMbps'] as num?)?.toDouble() ?? 0.0,
      minThroughputMbps:
          (map['minThroughputMbps'] as num?)?.toDouble() ?? 0.0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      jitterMs: (map['jitterMs'] as num?)?.toDouble(),
      lossPercent: (map['lossPercent'] as num?)?.toDouble(),
      lostPackets: (map['lostPackets'] as num?)?.toInt(),
      totalPackets: (map['totalPackets'] as num?)?.toInt(),
      retransmits: (map['retransmits'] as num?)?.toInt() ?? 0,
      baselinePingMs: (map['baselinePingMs'] as num?)?.toDouble(),
      loadedPingMs: (map['loadedPingMs'] as num?)?.toDouble(),
      bufferbloatDeltaMs: (map['bufferbloatDeltaMs'] as num?)?.toDouble(),
      samples: sampleList,
      rawJson: map['rawJson'] as String? ?? '',
      status: map['status'] as String? ?? 'completed',
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
