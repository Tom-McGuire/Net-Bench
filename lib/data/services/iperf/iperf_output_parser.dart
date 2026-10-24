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

  // Bidirectional pending interval state
  double? _pendingTxMbps;
  int _pendingTxRetransmits = 0;
  double? _pendingTxEndSec;

  // Summary parsed metrics
  double? _summaryAvgThroughput;
  int? _summaryTotalRetransmits;
  double? _summaryJitterMs;
  double? _summaryLossPercent;
  int? _summaryLostPackets;
  int? _summaryTotalPackets;
  int? _summaryTotalBytes;

  // Bidirectional summary tracking
  double? _summaryTxThroughput;
  double? _summaryRxThroughput;
  int? _summaryTxBytes;
  int? _summaryRxBytes;
  int _summaryTxRetransmits = 0;

  List<LiveSample> get collectedSamples => List.unmodifiable(_collectedSamples);

  // Regex patterns
  static final RegExp _summarySeparatorRegex = RegExp(r'^-{4,}\s*$');

  // TCP Interval Line: [ ID][Role] Interval Transfer Bitrate Retr
  // In standard tests: [  5] 0.00-1.00 sec ...
  // In --bidir tests: [  4][TX-C] 0.00-1.00 sec ..., [SUM][TX-C], or [SUM-TX-C]
  static final RegExp _tcpIntervalRegex = RegExp(
    r'\[\s*(\d+|SUM(?:-[A-Za-z0-9\-]+)?)\s*\](?:\[([A-Za-z0-9\-]+)\])?\s+([\d\.]+)-([\d\.]+)\s+sec\s+([\d\.]+)\s+([KMGT]?Bytes)\s+([\d\.]+)\s+([KMGT]?bits/sec)(?:\s+(\d+))?',
    caseSensitive: false,
  );

  // UDP Sender Interval Line: [ ID][Role] Interval Transfer Bitrate TotalDatagrams
  static final RegExp _udpSenderIntervalRegex = RegExp(
    r'\[\s*(\d+|SUM(?:-[A-Za-z0-9\-]+)?)\s*\](?:\[([A-Za-z0-9\-]+)\])?\s+([\d\.]+)-([\d\.]+)\s+sec\s+([\d\.]+)\s+([KMGT]?Bytes)\s+([\d\.]+)\s+([KMGT]?bits/sec)\s+(\d+)(?!\s*ms)',
    caseSensitive: false,
  );

  // UDP Receiver Interval Line: [ ID][Role] Interval Transfer Bitrate Jitter Lost/Total (Loss%)
  static final RegExp _udpReceiverIntervalRegex = RegExp(
    r'\[\s*(\d+|SUM(?:-[A-Za-z0-9\-]+)?)\s*\](?:\[([A-Za-z0-9\-]+)\])?\s+([\d\.]+)-([\d\.]+)\s+sec\s+([\d\.]+)\s+([KMGT]?Bytes)\s+([\d\.]+)\s+([KMGT]?bits/sec)\s+([\d\.]+)\s+ms\s+(\d+)/(\d+)\s+\(([\d\.]+)%\)',
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
        final streamToken = rxMatch.group(1) ?? '';
        final roleToken = rxMatch.group(2);
        final endSec = double.tryParse(rxMatch.group(4) ?? '') ?? 0.0;
        final bitrateVal = double.tryParse(rxMatch.group(7) ?? '') ?? 0.0;
        final bitrateUnit = rxMatch.group(8) ?? 'Mbits/sec';
        final jitter = double.tryParse(rxMatch.group(9) ?? '') ?? 0.0;
        final lost = int.tryParse(rxMatch.group(10) ?? '') ?? 0;
        final total = int.tryParse(rxMatch.group(11) ?? '') ?? 0;
        final lossPct = double.tryParse(rxMatch.group(12) ?? '') ?? 0.0;

        final mbps = convertToMbps(bitrateVal, bitrateUnit);
        final isSum = streamToken.startsWith('SUM');

        if (config.isBidirectional) {
          final role = (roleToken ?? (streamToken.contains('RX') ? 'RX' : (streamToken.contains('TX') ? 'TX' : ''))).toUpperCase();
          final isTx = role.contains('TX');

          if (!isSum && config.streams > 1) {
            final streamId = int.tryParse(streamToken) ?? 1;
            _pendingStreamThroughput[streamId] = mbps;
            return null;
          }

          if (isTx) {
            _pendingTxMbps = mbps;
            _pendingTxEndSec = endSec;
            if (config.streams == 1) {
              final streamId = int.tryParse(streamToken) ?? 1;
              _pendingStreamThroughput[streamId] = mbps;
            }
            return null;
          } else {
            if (config.streams == 1) {
              final streamId = int.tryParse(streamToken) ?? 2;
              _pendingStreamThroughput[streamId] = mbps;
            }
            final totalMbps = (_pendingTxMbps ?? 0.0) + mbps;
            _pendingTxMbps = null;
            _pendingTxEndSec = null;

            _currentIntervalIndex++;
            final sample = LiveSample(
              interval: _currentIntervalIndex,
              secondsElapsed: endSec,
              throughputMbps: totalMbps,
              perStreamMbps: Map.from(_pendingStreamThroughput),
              jitterMs: jitter,
              lostPercent: lossPct,
              lostPackets: lost,
              totalPackets: total,
            );
            _pendingStreamThroughput.clear();
            _collectedSamples.add(sample);
            return sample;
          }
        }

        if (isSum || config.streams == 1) {
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
          final streamId = int.tryParse(streamToken) ?? 1;
          _pendingStreamThroughput[streamId] = mbps;
          return null;
        }
      }

      // 2. Try UDP Sender line (has datagrams, NOT retransmits!)
      final txMatch = _udpSenderIntervalRegex.firstMatch(trimmed);
      if (txMatch != null) {
        final streamToken = txMatch.group(1) ?? '';
        final roleToken = txMatch.group(2);
        final endSec = double.tryParse(txMatch.group(4) ?? '') ?? 0.0;
        final bitrateVal = double.tryParse(txMatch.group(7) ?? '') ?? 0.0;
        final bitrateUnit = txMatch.group(8) ?? 'Mbits/sec';
        final totalDatagrams = int.tryParse(txMatch.group(9) ?? '') ?? 0;

        final mbps = convertToMbps(bitrateVal, bitrateUnit);
        final isSum = streamToken.startsWith('SUM');

        if (config.isBidirectional) {
          final role = (roleToken ?? (streamToken.contains('RX') ? 'RX' : (streamToken.contains('TX') ? 'TX' : ''))).toUpperCase();
          final isTx = role.contains('TX');

          if (!isSum && config.streams > 1) {
            final streamId = int.tryParse(streamToken) ?? 1;
            _pendingStreamThroughput[streamId] = mbps;
            return null;
          }

          if (isTx) {
            _pendingTxMbps = mbps;
            _pendingTxEndSec = endSec;
            if (config.streams == 1) {
              final streamId = int.tryParse(streamToken) ?? 1;
              _pendingStreamThroughput[streamId] = mbps;
            }
            return null;
          } else {
            if (config.streams == 1) {
              final streamId = int.tryParse(streamToken) ?? 2;
              _pendingStreamThroughput[streamId] = mbps;
            }
            final totalMbps = (_pendingTxMbps ?? 0.0) + mbps;
            _pendingTxMbps = null;
            _pendingTxEndSec = null;

            _currentIntervalIndex++;
            final sample = LiveSample(
              interval: _currentIntervalIndex,
              secondsElapsed: endSec,
              throughputMbps: totalMbps,
              perStreamMbps: Map.from(_pendingStreamThroughput),
              totalPackets: totalDatagrams,
              retransmits: 0,
            );
            _pendingStreamThroughput.clear();
            _collectedSamples.add(sample);
            return sample;
          }
        }

        if (isSum || config.streams == 1) {
          _currentIntervalIndex++;
          final sample = LiveSample(
            interval: _currentIntervalIndex,
            secondsElapsed: endSec,
            throughputMbps: mbps,
            perStreamMbps: Map.from(_pendingStreamThroughput),
            totalPackets: totalDatagrams,
            retransmits: 0,
          );
          _pendingStreamThroughput.clear();
          _collectedSamples.add(sample);
          return sample;
        } else {
          final streamId = int.tryParse(streamToken) ?? 1;
          _pendingStreamThroughput[streamId] = mbps;
          return null;
        }
      }
    }

    // TCP Interval Line
    final tcpMatch = _tcpIntervalRegex.firstMatch(trimmed);
    if (tcpMatch != null) {
      final streamToken = tcpMatch.group(1) ?? '';
      final roleToken = tcpMatch.group(2);
      final endSec = double.tryParse(tcpMatch.group(4) ?? '') ?? 0.0;
      final bitrateVal = double.tryParse(tcpMatch.group(7) ?? '') ?? 0.0;
      final bitrateUnit = tcpMatch.group(8) ?? 'Mbits/sec';
      final retrans = int.tryParse(tcpMatch.group(9) ?? '') ?? 0;

      final mbps = convertToMbps(bitrateVal, bitrateUnit);
      final isSum = streamToken.startsWith('SUM');

      if (config.isBidirectional) {
        final role = (roleToken ?? (streamToken.contains('RX') ? 'RX' : (streamToken.contains('TX') ? 'TX' : ''))).toUpperCase();
        final isTx = role.contains('TX');

        // Multi-stream intermediate line
        if (!isSum && config.streams > 1) {
          final streamId = int.tryParse(streamToken) ?? 1;
          _pendingStreamThroughput[streamId] = mbps;
          return null;
        }

        // TX half (either [SUM][TX-C] or single-stream [ID][TX-C])
        if (isTx) {
          // If a previous TX was never matched by an RX (rare interval desync), flush it
          if (_pendingTxMbps != null && _pendingTxEndSec != null && endSec > _pendingTxEndSec!) {
            _currentIntervalIndex++;
            _collectedSamples.add(LiveSample(
              interval: _currentIntervalIndex,
              secondsElapsed: _pendingTxEndSec!,
              throughputMbps: _pendingTxMbps!,
              perStreamMbps: Map.from(_pendingStreamThroughput),
              retransmits: _pendingTxRetransmits,
            ));
            _pendingStreamThroughput.clear();
          }

          _pendingTxMbps = mbps;
          _pendingTxRetransmits = retrans;
          _pendingTxEndSec = endSec;
          if (config.streams == 1) {
            final streamId = int.tryParse(streamToken) ?? 1;
            _pendingStreamThroughput[streamId] = mbps;
          }
          return null;
        } else {
          // RX half: combines with pending TX half into full-duplex aggregate
          if (config.streams == 1) {
            final streamId = int.tryParse(streamToken) ?? 2;
            _pendingStreamThroughput[streamId] = mbps;
          }

          final totalMbps = (_pendingTxMbps ?? 0.0) + mbps;
          final totalRetrans = _pendingTxRetransmits + retrans;
          _pendingTxMbps = null;
          _pendingTxRetransmits = 0;
          _pendingTxEndSec = null;

          _currentIntervalIndex++;
          final sample = LiveSample(
            interval: _currentIntervalIndex,
            secondsElapsed: endSec,
            throughputMbps: totalMbps,
            perStreamMbps: Map.from(_pendingStreamThroughput),
            retransmits: totalRetrans,
          );
          _pendingStreamThroughput.clear();
          _collectedSamples.add(sample);
          return sample;
        }
      }

      // Standard non-bidirectional mode
      if (isSum || config.streams == 1) {
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
        final streamId = int.tryParse(streamToken) ?? 1;
        _pendingStreamThroughput[streamId] = mbps;
        return null;
      }
    }

    return null;
  }

  void _parseSummaryLine(String line) {
    final tcpMatch = _tcpIntervalRegex.firstMatch(line);
    if (tcpMatch != null) {
      final streamToken = tcpMatch.group(1) ?? '';
      final roleToken = tcpMatch.group(2);
      final transferVal = double.tryParse(tcpMatch.group(5) ?? '') ?? 0.0;
      final transferUnit = tcpMatch.group(6) ?? 'Bytes';
      final bitrateVal = double.tryParse(tcpMatch.group(7) ?? '') ?? 0.0;
      final bitrateUnit = tcpMatch.group(8) ?? 'Mbits/sec';
      final retrans = int.tryParse(tcpMatch.group(9) ?? '') ?? 0;

      final isSum = streamToken.startsWith('SUM') || config.streams == 1;

      if (isSum) {
        final mbps = convertToMbps(bitrateVal, bitrateUnit);
        final bytes = convertToBytes(transferVal, transferUnit);

        if (config.isBidirectional) {
          final role = (roleToken ?? (streamToken.contains('RX') ? 'RX' : (streamToken.contains('TX') ? 'TX' : ''))).toUpperCase();
          final isTx = role.contains('TX');
          final isRx = role.contains('RX');

          if (isTx && line.contains('sender')) {
            _summaryTxThroughput = mbps;
            _summaryTxBytes = bytes;
            _summaryTxRetransmits = retrans;
          } else if (isRx && (line.contains('receiver') || _summaryRxThroughput == null)) {
            _summaryRxThroughput = mbps;
            _summaryRxBytes = bytes;
          }

          _summaryAvgThroughput = (_summaryTxThroughput ?? 0.0) + (_summaryRxThroughput ?? 0.0);
          _summaryTotalBytes = (_summaryTxBytes ?? 0) + (_summaryRxBytes ?? 0);
          _summaryTotalRetransmits = _summaryTxRetransmits;
        } else {
          _summaryAvgThroughput = mbps;
          _summaryTotalBytes = bytes;
          if (line.contains('sender')) {
            _summaryTotalRetransmits = retrans;
          }
        }
      }
    }

    final udpRxMatch = _udpReceiverIntervalRegex.firstMatch(line);
    if (udpRxMatch != null) {
      final streamToken = udpRxMatch.group(1) ?? '';
      final roleToken = udpRxMatch.group(2);
      final transferVal = double.tryParse(udpRxMatch.group(5) ?? '') ?? 0.0;
      final transferUnit = udpRxMatch.group(6) ?? 'Bytes';
      final bitrateVal = double.tryParse(udpRxMatch.group(7) ?? '') ?? 0.0;
      final bitrateUnit = udpRxMatch.group(8) ?? 'Mbits/sec';
      final isSum = streamToken.startsWith('SUM') || config.streams == 1;

      if (isSum) {
        final mbps = convertToMbps(bitrateVal, bitrateUnit);
        final bytes = convertToBytes(transferVal, transferUnit);

        if (config.isBidirectional) {
          final role = (roleToken ?? (streamToken.contains('RX') ? 'RX' : (streamToken.contains('TX') ? 'TX' : ''))).toUpperCase();
          final isTx = role.contains('TX');
          final isRx = role.contains('RX');

          if (isTx && line.contains('sender')) {
            _summaryTxThroughput = mbps;
            _summaryTxBytes = bytes;
          } else if (isRx && (line.contains('receiver') || _summaryRxThroughput == null)) {
            _summaryRxThroughput = mbps;
            _summaryRxBytes = bytes;
          }
          _summaryAvgThroughput = (_summaryTxThroughput ?? 0.0) + (_summaryRxThroughput ?? 0.0);
          _summaryTotalBytes = (_summaryTxBytes ?? 0) + (_summaryRxBytes ?? 0);
        } else {
          _summaryAvgThroughput = mbps;
          _summaryTotalBytes = bytes;
        }

        _summaryJitterMs = double.tryParse(udpRxMatch.group(9) ?? '');
        _summaryLostPackets = int.tryParse(udpRxMatch.group(10) ?? '');
        _summaryTotalPackets = int.tryParse(udpRxMatch.group(11) ?? '');
        _summaryLossPercent = double.tryParse(udpRxMatch.group(12) ?? '');
      }
    }
  }

  LiveSample? _tryParseJsonChunk(String jsonText) {
    try {
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      // 1. Line-delimited event format (iperf3 --json-stream)
      if (map['event'] == 'interval' && map.containsKey('data')) {
        final data = map['data'] as Map<String, dynamic>? ?? {};
        final sum = data['sum'] as Map<String, dynamic>? ?? {};
        final sumBidir = data['sum_bidir_reverse'] as Map<String, dynamic>?;

        final endSec = (sum['end'] as num?)?.toDouble() ?? 0.0;
        double bps = (sum['bits_per_second'] as num?)?.toDouble() ?? 0.0;
        int retr = (sum['retransmits'] as num?)?.toInt() ?? 0;
        final jitter = (sum['jitter_ms'] as num?)?.toDouble();
        int? lost = (sum['lost_packets'] as num?)?.toInt();
        int? total = (sum['packets'] as num?)?.toInt();
        double? lossPct = (sum['lost_percent'] as num?)?.toDouble();

        if (sumBidir != null) {
          bps += (sumBidir['bits_per_second'] as num?)?.toDouble() ?? 0.0;
          retr += (sumBidir['retransmits'] as num?)?.toInt() ?? 0;
          if (sumBidir.containsKey('lost_packets') && lost != null) {
            lost += (sumBidir['lost_packets'] as num?)?.toInt() ?? 0;
          }
          if (sumBidir.containsKey('packets') && total != null) {
            total += (sumBidir['packets'] as num?)?.toInt() ?? 0;
          }
        }

        final streamsList = data['streams'] as List<dynamic>? ?? [];
        final streamMap = <int, double>{};
        for (final st in streamsList) {
          if (st is Map<String, dynamic>) {
            final sock = (st['socket'] as num?)?.toInt();
            final sBps = (st['bits_per_second'] as num?)?.toDouble();
            if (sock != null && sBps != null) {
              streamMap[sock] = sBps / 1000000.0;
            }
          }
        }

        _currentIntervalIndex++;
        return LiveSample(
          interval: _currentIntervalIndex,
          secondsElapsed: endSec,
          throughputMbps: bps / 1000000.0,
          perStreamMbps: streamMap,
          retransmits: retr,
          jitterMs: jitter,
          lostPackets: lost,
          totalPackets: total,
          lostPercent: lossPct,
        );
      }

      if (map['event'] == 'end' && map.containsKey('data')) {
        final data = map['data'] as Map<String, dynamic>? ?? {};
        final sumSent = data['sum_sent'] as Map<String, dynamic>? ?? {};
        final sumReceived = data['sum_received'] as Map<String, dynamic>? ?? {};
        final sumSentBidir = data['sum_sent_bidir_reverse'] as Map<String, dynamic>? ?? {};
        final sumReceivedBidir = data['sum_received_bidir_reverse'] as Map<String, dynamic>? ?? {};

        double bps = (sumReceived['bits_per_second'] as num?)?.toDouble() ??
            (sumSent['bits_per_second'] as num?)?.toDouble() ??
            0.0;
        int bytes = (sumReceived['bytes'] as num?)?.toInt() ??
            (sumSent['bytes'] as num?)?.toInt() ??
            0;
        int retr = (sumSent['retransmits'] as num?)?.toInt() ?? 0;

        if (sumSentBidir.isNotEmpty || sumReceivedBidir.isNotEmpty) {
          final bidirBps = (sumReceivedBidir['bits_per_second'] as num?)?.toDouble() ??
              (sumSentBidir['bits_per_second'] as num?)?.toDouble() ??
              0.0;
          final bidirBytes = (sumReceivedBidir['bytes'] as num?)?.toInt() ??
              (sumSentBidir['bytes'] as num?)?.toInt() ??
              0;
          final bidirRetr = (sumSentBidir['retransmits'] as num?)?.toInt() ?? 0;

          bps += bidirBps;
          bytes += bidirBytes;
          retr += bidirRetr;
        }

        if (bps > 0) {
          _summaryAvgThroughput = bps / 1000000.0;
        }
        if (bytes > 0) {
          _summaryTotalBytes = bytes;
        }
        _summaryTotalRetransmits = retr;
        return null;
      }

      // 2. Legacy / static full JSON structure
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
    final avgThroughput = (_summaryAvgThroughput != null && _summaryAvgThroughput! > 0)
        ? _summaryAvgThroughput!
        : (_collectedSamples.isNotEmpty
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

  static int convertToBytes(double val, String unit) {
    final u = unit.toLowerCase().trim();
    if (u.contains('gbytes')) {
      return (val * 1024 * 1024 * 1024).round();
    } else if (u.contains('mbytes')) {
      return (val * 1024 * 1024).round();
    } else if (u.contains('kbytes')) {
      return (val * 1024).round();
    }
    return val.round();
  }
}
