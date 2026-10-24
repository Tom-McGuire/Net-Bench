import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';

class ExportService {
  /// Sanitize cell to prevent CSV formula injection in spreadsheet software.
  static dynamic sanitizeCsvCell(dynamic val) {
    if (val is String) {
      if (val.isNotEmpty &&
          (val.startsWith('=') ||
              val.startsWith('+') ||
              val.startsWith('-') ||
              val.startsWith('@') ||
              val.startsWith('\t') ||
              val.startsWith('\r'))) {
        return "'$val";
      }
    }
    return val;
  }

  /// Sanitizes string for safe filename across Windows, macOS, and Linux.
  static String sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Converts a benchmark run into CSV format string.
  String generateCsv(BenchmarkResult result) {
    final List<List<dynamic>> rawRows = [
      ['Metric', 'Value'],
      ['Run ID', result.id],
      ['Timestamp', result.timestamp.toIso8601String()],
      ['Profile', result.profileName],
      ['Target Host', result.targetHost],
      ['Port', result.port],
      ['Protocol', result.protocol.toUpperCase()],
      ['Direction', result.direction],
      ['Streams', result.streams],
      ['Duration (s)', result.durationSeconds],
      ['Avg Throughput (Mbps)', result.avgThroughputMbps],
      ['Peak Throughput (Mbps)', result.peakThroughputMbps],
      ['Min Throughput (Mbps)', result.minThroughputMbps],
      ['Total Bytes Transferred', result.totalBytes],
      ['Retransmits', result.retransmits],
      ['Jitter (ms)', result.jitterMs ?? 'N/A'],
      ['Packet Loss (%)', result.lossPercent ?? 'N/A'],
      ['Baseline Ping (ms)', result.baselinePingMs ?? 'N/A'],
      ['Loaded Ping (ms)', result.loadedPingMs ?? 'N/A'],
      ['Bufferbloat Delta (ms)', result.bufferbloatDeltaMs ?? 'N/A'],
      [],
      [
        'Interval',
        'Elapsed (s)',
        'Throughput (Mbps)',
        'Retransmits',
        'Jitter (ms)',
        'Loss (%)',
        'Ping RTT (ms)',
      ],
    ];

    for (final sample in result.samples) {
      rawRows.add([
        sample.interval,
        sample.secondsElapsed,
        sample.throughputMbps,
        sample.retransmits,
        sample.jitterMs ?? '',
        sample.lostPercent ?? '',
        sample.pingRttMs ?? '',
      ]);
    }

    final sanitizedRows = rawRows
        .map((row) => row.map((cell) => sanitizeCsvCell(cell)).toList())
        .toList();

    return Csv().encode(sanitizedRows);
  }

  /// Converts a benchmark run into formatted JSON string.
  String generateJson(BenchmarkResult result) {
    const encoder = JsonEncoder.withIndent('  ');
    final map = result.toMap();
    try {
      map['samples'] = jsonDecode(map['samples'] as String);
    } catch (_) {}
    return encoder.convert(map);
  }

  /// Prompts user to save CSV file to disk.
  Future<String?> exportCsvWithDialog(BenchmarkResult result) async {
    final csvContent = generateCsv(result);
    final cleanProfile = sanitizeFileName(result.profileName);
    final fileName = 'net_bench_${cleanProfile}_${result.id}.csv';

    final saveUri = await FilePicker.saveFile(
      dialogTitle: 'Export Benchmark CSV Report',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
    );

    if (saveUri != null) {
      final file = File.fromUri(saveUri);
      if (!await file.exists()) {
        await file.writeAsString(csvContent);
      }
      return file.path;
    }
    return null;
  }

  /// Prompts user to save JSON report to disk.
  Future<String?> exportJsonWithDialog(BenchmarkResult result) async {
    final jsonContent = generateJson(result);
    final cleanProfile = sanitizeFileName(result.profileName);
    final fileName = 'net_bench_${cleanProfile}_${result.id}.json';

    final saveUri = await FilePicker.saveFile(
      dialogTitle: 'Export Benchmark JSON Report',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(jsonContent)),
    );

    if (saveUri != null) {
      final file = File.fromUri(saveUri);
      if (!await file.exists()) {
        await file.writeAsString(jsonContent);
      }
      return file.path;
    }
    return null;
  }
}
