import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/services/iperf/iperf_output_parser.dart';
import 'package:net_bench/domain/models/benchmark_config.dart';

void main() {
  group('IPerfOutputParser - Real iPerf3 Fixture Parsing', () {
    test('parses TCP interval samples correctly and extracts throughput and retransmits', () {
      const config = BenchmarkConfig(streams: 1, protocol: 'tcp');
      final parser = IPerfOutputParser(config: config);

      const line = '[  5]   1.00-2.00   sec   112 MBytes   941 Mbits/sec    2   421 KBytes';
      final sample = parser.parseLine(line);

      expect(sample, isNotNull);
      expect(sample!.throughputMbps, closeTo(941.0, 0.01));
      expect(sample.retransmits, equals(2));
      expect(sample.jitterMs, isNull);
    });

    test('ignores summary sender and receiver lines during interval parsing', () {
      const config = BenchmarkConfig(streams: 1, protocol: 'tcp');
      final parser = IPerfOutputParser(config: config);

      const senderLine = '[  5]   0.00-10.00  sec  1.09 GBytes   940 Mbits/sec    5             sender';
      const receiverLine = '[  5]   0.00-10.04  sec  1.09 GBytes   935 Mbits/sec                  receiver';
      const dividerLine = '- - - - - - - - - - - - - - - - - - - - - - - - -';

      expect(parser.parseLine(dividerLine), isNull);
      expect(parser.parseLine(senderLine), isNull);
      expect(parser.parseLine(receiverLine), isNull);
    });

    test('parses multi-stream [SUM] lines with priority', () {
      const config = BenchmarkConfig(streams: 2, protocol: 'tcp');
      final parser = IPerfOutputParser(config: config);

      const stream1Line = '[  5]   1.00-2.00   sec  56.0 MBytes   470 Mbits/sec    1';
      const stream2Line = '[  7]   1.00-2.00   sec  56.0 MBytes   470 Mbits/sec    1';
      const sumLine = '[SUM]   1.00-2.00   sec   112 MBytes   940 Mbits/sec    2';

      // Intermediate stream lines accumulate into pending map and return null
      expect(parser.parseLine(stream1Line), isNull);
      expect(parser.parseLine(stream2Line), isNull);

      // SUM line emits the complete interval sample
      final sample = parser.parseLine(sumLine);
      expect(sample, isNotNull);
      expect(sample!.throughputMbps, closeTo(940.0, 0.01));
      expect(sample.retransmits, equals(2));
      expect(sample.perStreamMbps.length, equals(2));
    });

    test('parses various bandwidth units: Kbits/sec, Mbits/sec, Gbits/sec, Tbits/sec', () {
      expect(IPerfOutputParser.convertToMbps(1000.0, 'Kbits/sec'), closeTo(1.0, 0.001));
      expect(IPerfOutputParser.convertToMbps(500.0, 'Mbits/sec'), closeTo(500.0, 0.001));
      expect(IPerfOutputParser.convertToMbps(2.5, 'Gbits/sec'), closeTo(2500.0, 0.001));
      expect(IPerfOutputParser.convertToMbps(1.2, 'Tbits/sec'), closeTo(1200000.0, 0.001));
    });

    test('distinguishes UDP sender datagrams from UDP receiver jitter/loss', () {
      const config = BenchmarkConfig(streams: 1, protocol: 'udp');
      final parser = IPerfOutputParser(config: config);

      // Sender line only reports total datagrams, NOT lost/jitter
      const udpSenderLine = '[  5]   1.00-2.00   sec   119 KBytes   975 Kbits/sec  85';
      final senderSample = parser.parseLine(udpSenderLine);
      expect(senderSample, isNotNull);
      expect(senderSample!.throughputMbps, closeTo(0.975, 0.001));
      expect(senderSample.retransmits, equals(0)); // UDP sender datagrams must not become TCP retransmits
      expect(senderSample.jitterMs, isNull);

      // Receiver line reports jitter, lost/total, percentage
      const udpReceiverLine = '[  5]   2.00-3.00   sec   119 KBytes   975 Kbits/sec  0.032 ms  0/85 (0%)';
      final receiverSample = parser.parseLine(udpReceiverLine);
      expect(receiverSample, isNotNull);
      expect(receiverSample!.jitterMs, closeTo(0.032, 0.0001));
      expect(receiverSample.lostPackets, equals(0));
      expect(receiverSample.totalPackets, equals(85));
      expect(receiverSample.lostPercent, closeTo(0.0, 0.001));
    });

    test('compileResult calculates accurate arithmetic means and peak values', () {
      const config = BenchmarkConfig(
        targetHost: '192.168.1.50',
        port: 5201,
        durationSeconds: 3,
        streams: 1,
      );
      final parser = IPerfOutputParser(config: config);

      final logs = [
        'Connecting to host 192.168.1.50, port 5201',
        '[  5]   0.00-1.00   sec   100 MBytes   800 Mbits/sec    0',
        '[  5]   1.00-2.00   sec   120 MBytes   960 Mbits/sec    1',
        '[  5]   2.00-3.00   sec   110 MBytes   880 Mbits/sec    0',
        '- - - - - - - - - - - - - - - - - - - - - - - - -',
        '[  5]   0.00-3.00   sec   330 MBytes   880 Mbits/sec    1             sender',
        '[  5]   0.00-3.00   sec   330 MBytes   878 Mbits/sec                  receiver',
      ];

      for (final line in logs) {
        parser.parseLine(line);
      }

      final result = parser.compileResult(
        startTime: DateTime.now(),
        rawOutput: logs.join('\n'),
        status: 'completed',
      );

      expect(result.avgThroughputMbps, closeTo(878.0, 1.0));
      expect(result.peakThroughputMbps, closeTo(960.0, 0.1));
      expect(result.retransmits, equals(1));
      expect(result.targetHost, equals('192.168.1.50'));
    });
  });
}
