import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/services/export/export_service.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/live_sample.dart';

void main() {
  group('ExportService Tests', () {
    late ExportService exportService;
    late BenchmarkResult sampleResult;

    setUp(() {
      exportService = ExportService();
      sampleResult = BenchmarkResult(
        id: 'bench-12345',
        timestamp: DateTime(2026, 11, 6, 14, 30, 0),
        profileName: '1G Full-Duplex',
        targetHost: '192.168.1.100',
        port: 5201,
        protocol: 'tcp',
        direction: 'bidirectional',
        streams: 4,
        durationSeconds: 10,
        avgThroughputMbps: 940.5,
        peakThroughputMbps: 980.2,
        minThroughputMbps: 910.0,
        totalBytes: 1250000000,
        retransmits: 5,
        jitterMs: 0.25,
        lossPercent: 0.0,
        baselinePingMs: 12.4,
        loadedPingMs: 18.6,
        bufferbloatDeltaMs: 6.2,
        samples: const [
          LiveSample(
            interval: 1,
            secondsElapsed: 1.0,
            throughputMbps: 935.0,
            retransmits: 2,
            jitterMs: 0.2,
            lostPercent: 0.0,
            pingRttMs: 14.0,
          ),
          LiveSample(
            interval: 2,
            secondsElapsed: 2.0,
            throughputMbps: 946.0,
            retransmits: 3,
            jitterMs: 0.3,
            lostPercent: 0.0,
            pingRttMs: 18.6,
          ),
        ],
        rawJson: '{"end":{"sum_sent":{"bits_per_second":940500000}}}',
        status: 'completed',
      );
    });

    test('generateCsv formats headers, summary rows, and sample rows correctly', () {
      final csv = exportService.generateCsv(sampleResult);

      expect(csv, contains('Metric,Value'));
      expect(csv, contains('Run ID,bench-12345'));
      expect(csv, contains('Profile,1G Full-Duplex'));
      expect(csv, contains('Target Host,192.168.1.100'));
      expect(csv, contains('Port,5201'));
      expect(csv, contains('Protocol,TCP'));
      expect(csv, contains('Direction,bidirectional'));
      expect(csv, contains('Streams,4'));
      expect(csv, contains('Duration (s),10'));
      expect(csv, contains('Avg Throughput (Mbps),940.5'));
      expect(csv, contains('Bufferbloat Delta (ms),6.2'));
      expect(csv, contains('Interval,Elapsed (s),Throughput (Mbps),Retransmits,Jitter (ms),Loss (%),Ping RTT (ms)'));
      expect(csv, contains('1,1.0,935.0,2,0.2,0.0,14.0'));
      expect(csv, contains('2,2.0,946.0,3,0.3,0.0,18.6'));
    });

    test('generateCsv handles nullable metrics with N/A and blank values', () {
      final minimalResult = BenchmarkResult(
        id: 'bench-minimal',
        timestamp: DateTime(2026, 11, 6, 15, 0, 0),
        profileName: 'Default TCP',
        targetHost: '10.0.0.1',
        port: 5201,
        protocol: 'tcp',
        direction: 'upload',
        streams: 1,
        durationSeconds: 5,
        avgThroughputMbps: 500.0,
        peakThroughputMbps: 500.0,
        minThroughputMbps: 500.0,
        totalBytes: 500000,
        retransmits: 0,
        samples: const [
          LiveSample(
            interval: 1,
            secondsElapsed: 1.0,
            throughputMbps: 500.0,
            retransmits: 0,
          ),
        ],
      );

      final csv = exportService.generateCsv(minimalResult);

      expect(csv, contains('Jitter (ms),N/A'));
      expect(csv, contains('Packet Loss (%),N/A'));
      expect(csv, contains('Baseline Ping (ms),N/A'));
      expect(csv, contains('Loaded Ping (ms),N/A'));
      expect(csv, contains('Bufferbloat Delta (ms),N/A'));
      // In the sample row, null values are empty strings
      expect(csv, contains('1,1.0,500.0,0,,,'));
    });

    test('generateJson outputs valid and structured JSON', () {
      final jsonStr = exportService.generateJson(sampleResult);
      expect(jsonStr, isNotEmpty);

      final decoded = jsonDecode(jsonStr);
      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded['id'], equals('bench-12345'));
      expect(decoded['profileName'], equals('1G Full-Duplex'));
      expect(decoded['avgThroughputMbps'], equals(940.5));
      expect(decoded['samples'], isA<List>());
      expect((decoded['samples'] as List).length, equals(2));
      expect(decoded['samples'][0]['throughputMbps'], equals(935.0));
    });

    test('sanitizeCsvCell escapes formula injection characters', () {
      expect(ExportService.sanitizeCsvCell('=SUM(A1:A10)'), equals("'=SUM(A1:A10)"));
      expect(ExportService.sanitizeCsvCell('+12345'), equals("'+12345"));
      expect(ExportService.sanitizeCsvCell('-cmd|calc'), equals("'-cmd|calc"));
      expect(ExportService.sanitizeCsvCell('@special'), equals("'@special"));
      expect(ExportService.sanitizeCsvCell('\ttext'), equals("'\ttext"));
      expect(ExportService.sanitizeCsvCell('\rtext'), equals("'\rtext"));

      // Non-formula strings and numbers should remain unmodified
      expect(ExportService.sanitizeCsvCell('Normal Text'), equals('Normal Text'));
      expect(ExportService.sanitizeCsvCell(42), equals(42));
      expect(ExportService.sanitizeCsvCell(940.5), equals(940.5));
      expect(ExportService.sanitizeCsvCell(''), equals(''));
    });

    test('sanitizeFileName removes disallowed characters and spaces', () {
      expect(ExportService.sanitizeFileName('run: 1/2*3?4"5<6>7|8'), equals('run__1_2_3_4_5_6_7_8'));
      expect(ExportService.sanitizeFileName('test profile  name'), equals('test_profile_name'));
    });
  });
}
