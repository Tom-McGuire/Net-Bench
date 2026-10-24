class LiveSample {
  const LiveSample({
    required this.interval,
    required this.secondsElapsed,
    required this.throughputMbps,
    this.perStreamMbps = const {},
    this.retransmits = 0,
    this.jitterMs,
    this.lostPercent,
    this.lostPackets,
    this.totalPackets,
    this.pingRttMs,
  });

  final int interval;
  final double secondsElapsed;
  final double throughputMbps;
  final Map<int, double> perStreamMbps;
  final int retransmits;
  final double? jitterMs;
  final double? lostPercent;
  final int? lostPackets;
  final int? totalPackets;
  final double? pingRttMs;

  Map<String, dynamic> toMap() => {
        'interval': interval,
        'secondsElapsed': secondsElapsed,
        'throughputMbps': throughputMbps,
        'perStreamMbps': perStreamMbps.map((k, v) => MapEntry(k.toString(), v)),
        'retransmits': retransmits,
        'jitterMs': jitterMs,
        'lostPercent': lostPercent,
        'lostPackets': lostPackets,
        'totalPackets': totalPackets,
        'pingRttMs': pingRttMs,
      };

  factory LiveSample.fromMap(Map<String, dynamic> map) {
    final streamMapRaw = map['perStreamMbps'] as Map<String, dynamic>? ?? {};
    final streamMap = <int, double>{};
    streamMapRaw.forEach((k, v) {
      final streamId = int.tryParse(k);
      if (streamId != null) {
        streamMap[streamId] = (v as num).toDouble();
      }
    });

    return LiveSample(
      interval: map['interval'] as int? ?? 0,
      secondsElapsed: (map['secondsElapsed'] as num?)?.toDouble() ?? 0.0,
      throughputMbps: (map['throughputMbps'] as num?)?.toDouble() ?? 0.0,
      perStreamMbps: streamMap,
      retransmits: map['retransmits'] as int? ?? 0,
      jitterMs: (map['jitterMs'] as num?)?.toDouble(),
      lostPercent: (map['lostPercent'] as num?)?.toDouble(),
      lostPackets: map['lostPackets'] as int?,
      totalPackets: map['totalPackets'] as int?,
      pingRttMs: (map['pingRttMs'] as num?)?.toDouble(),
    );
  }
}
