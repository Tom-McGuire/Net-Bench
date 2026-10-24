import 'dart:convert';
import 'package:net_bench/domain/models/benchmark_config.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/live_sample.dart';

class IPerfOutputParser {
  IPerfOutputParser({required this.config});

  final BenchmarkConfig config;

  bool _inSummarySection = false;
  int _currentIntervalIndex = 0;
  final Map<int, double> _pendingStreamThroughput = {};
  final List<LiveSample> _collectedSamples = [];

  // Summary parsed metrics
  double? _summaryAvgThroughput;
  int? _summaryTotalRetransmits;
  double? _summaryJitterMs;
  double? _summaryLossPercent;
  int? _summaryLostPackets;
  int? _summaryTotalPackets;
  int? _summaryTotalBytes;

  List<LiveSample> get collectedSamples => List.unmodifiable(_collectedSamples);

  // Regex patterns
  static final RegExp _summarySeparatorRegex = RegExp(r'^-{4,}\s*$');

  // TCP Interval Line: [ ID] Interval Transfer Bitrate Retr
  static final RegExp _tcpIntervalRegex = RegExp(
    r'\[\s*(\d+|SUM)\]\s+([\d\.]+)-([\d\.]+)\s+sec\s+([\d\.]+)\s+([KMGT]?Bytes)\s+([\d\.]+)\s+([KMGT]?bits/sec)(?:\s+(\d+))?',
    caseSensitive: false,
  );

  // UDP Sender Interval Line: [ ID] Interval Transfer Bitrate TotalDatagrams
  static final RegExp _udpSenderIntervalRegex = RegExp(
    r'\[\s*(\d+|SUM)\]\s+([\d\.]+)-([\d\.]+)\s+sec\s+([\d\.]+)\s+([KMGT]?Bytes)\s+([\d\.]+)\s+([KMGT]?bits/sec)\s+(\d+)(?!\s*ms)',
    caseSensitive: false,
  );

  // UDP Receiver Interval Line: [ ID] Interval Transfer Bitrate Jitter Lost/Total (Loss%)
  static final RegExp _udpReceiverIntervalRegex = RegExp(
    r'\[\s*(\d+|SUM)\]\s+([\d\.]+)-([\d\.]+)\s+sec\s+([\d\.]+)\s+([KMGT]?Bytes)\s+([\d\.]+)\s+([KMGT]?bits/sec)\s+([\d\.]+)\s+ms\s+(\d+)/(\d+)\s+\(([\d\.]+)%\)',
    caseSensitive: false,
  );

  /// Feeds a raw stdout line into the parser.
  /// Returns a [LiveSample] if this line completed an interval, or null.
  LiveSample? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // Check for JSON Stream chunk (if iperf3 was launched with --json-stream)
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final jsonSample = _tryParseJsonChunk(trimmed);
      if (jsonSample != null) {
        _collectedSamples.add(jsonSample);
        return jsonSample;
      }
    }

    // Check for summary divider or sender/receiver marker lines
    if (_summarySeparatorRegex.hasMatch(trimmed)) {
      _inSummarySection = true;
      return null;
    }

    if (trimmed.contains('sender') || trimmed.contains('receiver')) {
      _inSummarySection = true;
      _parseSummaryLine(trimmed);
      return null;
    }

    if (_inSummarySection) {
      _parseSummaryLine(trimmed);
      return null;
    }

    // If UDP test
    if (config.isUdp) {
      // 1. Try UDP Receiver line (has ms jitter and loss%)
      final rxMatch = _udpReceiverIntervalRegex.firstMatch(trimmed);
      if (rxMatch != null) {
        final streamToken = rxMatch.group(1);
        final endSec = double.tryParse(rxMatch.group(3) ?? '') ?? 0.0;
        final bitrateVal = double.tryParse(rxMatch.group(6) ?? '') ?? 0.0;
        final bitrateUnit = rxMatch.group(7) ?? 'Mbits/sec';
        final jitter = double.tryParse(rxMatch.group(8) ?? '') ?? 0.0;
        final lost = int.tryParse(rxMatch.group(9) ?? '') ?? 0;
        final total = int.tryParse(rxMatch.group(10) ?? '') ?? 0;
        final lossPct = double.tryParse(rxMatch.group(11) ?? '') ?? 0.0;

        final mbps = convertToMbps(bitrateVal, bitrateUnit);

        if (streamToken == 'SUM' || config.streams == 1) {
          _currentIntervalIndex++;
          final sample = LiveSample(
            interval: _currentIntervalIndex,
            secondsElapsed: endSec,
            throughputMbps: mbps,
            perStreamMbps: Map.from(_pendingStreamThroughput),
            jitterMs: jitter,
            lostPercent: lossPct,
            lostPackets: lost,
            totalPackets: total,
          );
          _pendingStreamThroughput.clear();
          _collectedSamples.add(sample);
          return sample;
        } else {
          final streamId = int.tryParse(streamToken ?? '') ?? 1;
          _pendingStreamThroughput[streamId] = mbps;
          return null;
        }
      }

      // 2. Try UDP Sender line (has datagrams, NOT retransmits!)
      final txMatch = _udpSenderIntervalRegex.firstMatch(trimmed);
      if (txMatch != null) {
        final streamToken = txMatch.group(1);
        final endSec = double.tryParse(txMatch.group(3) ?? '') ?? 0.0;
        final bitrateVal = double.tryParse(txMatch.group(6) ?? '') ?? 0.0;
        final bitrateUnit = txMatch.group(7) ?? 'Mbits/sec';
        final totalDatagrams = int.tryParse(txMatch.group(8) ?? '') ?? 0;

        final mbps = convertToMbps(bitrateVal, bitrateUnit);

        if (streamToken == 'SUM' || config.streams == 1) {
          _currentIntervalIndex++;
          final sample = LiveSample(
            interval: _currentIntervalIndex,
            secondsElapsed: endSec,
            throughputMbps: mbps,
            perStreamMbps: Map.from(_pendingStreamThroughput),
            totalPackets: totalDatagrams,
            retransmits: 0, // Sender datagram count is not a TCP retransmit
          );
          _pendingStreamThroughput.clear();
          _collectedSamples.add(sample);
          return sample;
        } else {
          final streamId = int.tryParse(streamToken ?? '') ?? 1;
          _pendingStreamThroughput[streamId] = mbps;
          return null;
        }
      }
    }

    // TCP Interval Line
    final tcpMatch = _tcpIntervalRegex.firstMatch(trimmed);
    if (tcpMatch != null) {
      final streamToken = tcpMatch.group(1);
      final endSec = double.tryParse(tcpMatch.group(3) ?? '') ?? 0.0;
      final bitrateVal = double.tryParse(tcpMatch.group(6) ?? '') ?? 0.0;
      final bitrateUnit = tcpMatch.group(7) ?? 'Mbits/sec';
      final retrans = int.tryParse(tcpMatch.group(8) ?? '') ?? 0;

      final mbps = convertToMbps(bitrateVal, bitrateUnit);

      if (streamToken == 'SUM' || config.streams == 1) {
        _currentIntervalIndex++;
        final sample = LiveSample(
          interval: _currentIntervalIndex,
          secondsElapsed: endSec,
          throughputMbps: mbps,
          perStreamMbps: Map.from(_pendingStreamThroughput),
          retransmits: retrans,
        );
        _pendingStreamThroughput.clear();
        _collectedSamples.add(sample);
        return sample;
      } else {
        final streamId = int.tryParse(streamToken ?? '') ?? 1;
        _pendingStreamThroughput[streamId] = mbps;
        return null;
      }
    }

    return null;
  }

  void _parseSummaryLine(String line) {
    // e.g. [SUM]   0.00-10.00  sec  1.10 GBytes   942 Mbits/sec    4             sender
    final tcpMatch = _tcpIntervalRegex.firstMatch(line);
    if (tcpMatch != null && (tcpMatch.group(1) == 'SUM' || config.streams == 1)) {
      final bitrateVal = double.tryParse(tcpMatch.group(6) ?? '') ?? 0.0;
      final bitrateUnit = tcpMatch.group(7) ?? 'Mbits/sec';
      final retrans = int.tryParse(tcpMatch.group(8) ?? '') ?? 0;
      _summaryAvgThroughput = convertToMbps(bitrateVal, bitrateUnit);
      if (line.contains('sender')) {
        _summaryTotalRetransmits = retrans;
      }
    }

    final udpRxMatch = _udpReceiverIntervalRegex.firstMatch(line);
    if (udpRxMatch != null && (udpRxMatch.group(1) == 'SUM' || config.streams == 1)) {
      final bitrateVal = double.tryParse(udpRxMatch.group(6) ?? '') ?? 0.0;
      final bitrateUnit = udpRxMatch.group(7) ?? 'Mbits/sec';
      _summaryAvgThroughput = convertToMbps(bitrateVal, bitrateUnit);
      _summaryJitterMs = double.tryParse(udpRxMatch.group(8) ?? '');
      _summaryLostPackets = int.tryParse(udpRxMatch.group(9) ?? '');
      _summaryTotalPackets = int.tryParse(udpRxMatch.group(10) ?? '');
      _summaryLossPercent = double.tryParse(udpRxMatch.group(11) ?? '');
    }
  }

  LiveSample? _tryParseJsonChunk(String jsonText) {
    try {
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      // If it has "intervals"
      if (map.containsKey('intervals')) {
        final intervals = map['intervals'] as List<dynamic>;
        if (intervals.isNotEmpty) {
          final first = intervals.first as Map<String, dynamic>;
          final sum = first['sum'] as Map<String, dynamic>? ?? {};
          final endSec = (sum['end'] as num?)?.toDouble() ?? 0.0;
          final bps = (sum['bits_per_second'] as num?)?.toDouble() ?? 0.0;
          final retr = (sum['retransmits'] as num?)?.toInt() ?? 0;
          final jitter = (sum['jitter_ms'] as num?)?.toDouble();
          final lost = (sum['lost_packets'] as num?)?.toInt();
          final total = (sum['packets'] as num?)?.toInt();
          final lossPct = (sum['lost_percent'] as num?)?.toDouble();

          _currentIntervalIndex++;
          return LiveSample(
            interval: _currentIntervalIndex,
            secondsElapsed: endSec,
            throughputMbps: bps / 1000000.0,
            retransmits: retr,
            jitterMs: jitter,
            lostPackets: lost,
            totalPackets: total,
            lostPercent: lossPct,
          );
        }
      } else if (map.containsKey('end')) {
        // End summary block
        final end = map['end'] as Map<String, dynamic>;
        final sumReceived = end['sum_received'] as Map<String, dynamic>? ??
            end['sum_sent'] as Map<String, dynamic>? ??
            {};
        final bps = (sumReceived['bits_per_second'] as num?)?.toDouble();
        if (bps != null) {
          _summaryAvgThroughput = bps / 1000000.0;
        }
        _summaryTotalBytes = (sumReceived['bytes'] as num?)?.toInt();
        _summaryTotalRetransmits = (sumReceived['retransmits'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  /// Compiles the final BenchmarkResult with true arithmetic means and summary stats.
  BenchmarkResult compileResult({
    required DateTime startTime,
    required String rawOutput,
    required String status,
    String? errorMessage,
    double? baselinePingMs,
    double? loadedPingMs,
  }) {
    double sumThroughput = 0.0;
    double peakThroughput = 0.0;
    double minThroughput = double.infinity;
    int intervalRetransmits = 0;

    double sumJitter = 0.0;
    int jitterCount = 0;

    int totalLost = 0;
    int totalPackets = 0;

    for (final s in _collectedSamples) {
      sumThroughput += s.throughputMbps;
      if (s.throughputMbps > peakThroughput) peakThroughput = s.throughputMbps;
      if (s.throughputMbps < minThroughput) minThroughput = s.throughputMbps;

      intervalRetransmits += s.retransmits;

      if (s.jitterMs != null) {
        sumJitter += s.jitterMs!;
        jitterCount++;
      }
      if (s.lostPackets != null) totalLost += s.lostPackets!;
      if (s.totalPackets != null) totalPackets += s.totalPackets!;
    }

    if (minThroughput == double.infinity) minThroughput = 0.0;

    // Use summary values if captured, otherwise calculate true arithmetic mean
    final avgThroughput = _summaryAvgThroughput ??
        (_collectedSamples.isNotEmpty
            ? sumThroughput / _collectedSamples.length
            : 0.0);

    final finalRetransmits = _summaryTotalRetransmits ?? intervalRetransmits;

    final avgJitter = _summaryJitterMs ??
        (jitterCount > 0 ? (sumJitter / jitterCount) : null);

    final finalLost = _summaryLostPackets ?? (totalLost > 0 ? totalLost : null);
    final finalTotal = _summaryTotalPackets ?? (totalPackets > 0 ? totalPackets : null);
    final finalLossPct = _summaryLossPercent ??
        (finalTotal != null && finalTotal > 0
            ? ((finalLost ?? 0) / finalTotal) * 100
            : null);

    final approxBytes = _summaryTotalBytes ??
        ((avgThroughput * config.durationSeconds * 1000000) / 8).round();

    double? bufferbloatDelta;
    if (baselinePingMs != null && loadedPingMs != null) {
      bufferbloatDelta = loadedPingMs - baselinePingMs;
    }

    return BenchmarkResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: startTime,
      profileName: config.profileName,
      targetHost: config.targetHost,
      port: config.port,
      protocol: config.protocol,
      direction: config.direction,
      streams: config.streams,
      durationSeconds: config.durationSeconds,
      avgThroughputMbps: double.parse(avgThroughput.toStringAsFixed(2)),
      peakThroughputMbps: double.parse(peakThroughput.toStringAsFixed(2)),
      minThroughputMbps: double.parse(minThroughput.toStringAsFixed(2)),
      totalBytes: approxBytes,
      jitterMs: avgJitter != null
          ? double.parse(avgJitter.toStringAsFixed(3))
          : null,
      lossPercent: finalLossPct != null
          ? double.parse(finalLossPct.toStringAsFixed(2))
          : null,
      lostPackets: finalLost,
      totalPackets: finalTotal,
      retransmits: finalRetransmits,
      baselinePingMs: baselinePingMs,
      loadedPingMs: loadedPingMs,
      bufferbloatDeltaMs: bufferbloatDelta,
      samples: _collectedSamples,
      rawJson: rawOutput,
      status: status,
      errorMessage: errorMessage,
    );
  }

  static double convertToMbps(double val, String unit) {
    final u = unit.toLowerCase().trim();
    if (u.contains('tbits')) {
      return val * 1000000.0;
    } else if (u.contains('gbits')) {
      return val * 1000.0;
    } else if (u.contains('mbits')) {
      return val * 1.0;
    } else if (u.contains('kbits')) {
      return val / 1000.0;
    } else if (u.contains('bits')) {
      return val / 1000000.0;
    }
    return val;
  }
}
