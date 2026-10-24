import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/domain/models/benchmark_config.dart';
import 'package:net_bench/domain/models/benchmark_preset.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/live_sample.dart';

void main() {
  group('BenchmarkConfig CLI Arguments', () {
    test('Standard TCP test arguments', () {
      const config = BenchmarkConfig(
        targetHost: '192.168.1.10',
        port: 5201,
        protocol: 'tcp',
        direction: 'upload',
        streams: 4,
        durationSeconds: 10,
        intervalSeconds: 1.0,
      );

      final args = config.toCliArguments();
      expect(args, contains('-c'));
      expect(args[args.indexOf('-c') + 1], equals('192.168.1.10'));
      expect(args, contains('-p'));
      expect(args[args.indexOf('-p') + 1], equals('5201'));
      expect(args, contains('-P'));
      expect(args[args.indexOf('-P') + 1], equals('4'));
      expect(args, contains('-t'));
      expect(args[args.indexOf('-t') + 1], equals('10'));
      expect(args, contains('--forceflush'));
      expect(args, isNot(contains('-u')));
      expect(args, isNot(contains('-R')));
    });

    test('UDP reverse mode with bandwidth limit arguments', () {
      const config = BenchmarkConfig(
        targetHost: '10.0.0.1',
        port: 5201,
        protocol: 'udp',
        direction: 'download',
        streams: 1,
        durationSeconds: 15,
        udpBandwidthMbps: 250,
      );

      final args = config.toCliArguments();
      expect(args, contains('-u'));
      expect(args, contains('-R'));
      expect(args, contains('-b'));
      expect(args[args.indexOf('-b') + 1], equals('250M'));
    });

    test('Bidirectional full-duplex with custom socket buffer', () {
      const config = BenchmarkConfig(
        targetHost: '172.16.0.5',
        direction: 'bidirectional',
        streams: 8,
        socketBufferSizeKb: 1024,
      );

      final args = config.toCliArguments();
      expect(args, contains('--bidir'));
      expect(args, contains('-w'));
      expect(args[args.indexOf('-w') + 1], equals('1024K'));
    });
  });

  group('BenchmarkPreset Definitions', () {
    test('Has expected default presets', () {
      final presets = BenchmarkPreset.defaultPresets;
      expect(presets.length, equals(5));

      final names = presets.map((p) => p.name).toList();
      expect(names, contains('1G Full-Duplex'));
      expect(names, contains('UDP Jitter Check'));
      expect(names, contains('Bufferbloat Test'));
      expect(names, contains('10G Max Throughput'));
      expect(names, contains('Quick 5s Health Check'));
    });

    test('Bufferbloat preset has isBufferbloatPreset flag set', () {
      final bb = BenchmarkPreset.defaultPresets
          .firstWhere((p) => p.id == 'bufferbloat_test');
      expect(bb.isBufferbloatPreset, isTrue);
    });
  });

  group('Serialization & Parsing', () {
    test('BenchmarkResult roundtrip serialization', () {
      final now = DateTime.now();
      final sample = LiveSample(
        interval: 1,
        secondsElapsed: 1.0,
        throughputMbps: 942.5,
        retransmits: 2,
        jitterMs: 0.12,
        pingRttMs: 14.5,
      );

      final result = BenchmarkResult(
        id: '12345',
        timestamp: now,
        profileName: '1G Full-Duplex',
        targetHost: '192.168.1.5',
        port: 5201,
        protocol: 'tcp',
        direction: 'upload',
        streams: 4,
        durationSeconds: 10,
        avgThroughputMbps: 940.0,
        peakThroughputMbps: 955.2,
        minThroughputMbps: 910.0,
        totalBytes: 1175000000,
        jitterMs: 0.12,
        retransmits: 2,
        samples: [sample],
        rawJson: '{"test":"json"}',
        status: 'completed',
      );

      final map = result.toMap();
      final restored = BenchmarkResult.fromMap(map);

      expect(restored.id, equals('12345'));
      expect(restored.profileName, equals('1G Full-Duplex'));
      expect(restored.targetHost, equals('192.168.1.5'));
      expect(restored.avgThroughputMbps, equals(940.0));
      expect(restored.samples.length, equals(1));
      expect(restored.samples.first.throughputMbps, equals(942.5));
    });
  });
}
