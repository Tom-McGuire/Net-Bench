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
      expect(senderSample.retransmits, equals(0));
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

    test('parses single-stream bidirectional interval lines into aggregate full-duplex sample', () {
      const config = BenchmarkConfig(
        streams: 1,
        protocol: 'tcp',
        direction: 'bidirectional',
      );
      final parser = IPerfOutputParser(config: config);

      // iPerf3 --bidir with 1 stream emits [ 4][TX-C] then [ 6][RX-C]
      const txLine = '[  4][TX-C]   0.00-1.00   sec  1.60 GBytes  13.7 Gbits/sec    1';
      const rxLine = '[  6][RX-C]   0.00-1.00   sec  1.59 GBytes  13.6 Gbits/sec';

      // TX line holds pending half
      expect(parser.parseLine(txLine), isNull);

      // RX line completes full-duplex aggregate
      final sample = parser.parseLine(rxLine);
      expect(sample, isNotNull);
      // 13.7 Gbits/sec + 13.6 Gbits/sec = 27.3 Gbits/sec -> 27,300 Mbps
      expect(sample!.throughputMbps, closeTo(27300.0, 1.0));
      expect(sample.retransmits, equals(1));
      expect(sample.perStreamMbps[4], closeTo(13700.0, 1.0));
      expect(sample.perStreamMbps[6], closeTo(13600.0, 1.0));
    });

    test('parses multi-stream bidirectional interval [SUM] lines into aggregate full-duplex sample', () {
      const config = BenchmarkConfig(
        streams: 2,
        protocol: 'tcp',
        direction: 'bidirectional',
      );
      final parser = IPerfOutputParser(config: config);

      final lines = [
        '[  4][TX-C]   0.00-1.00   sec  1.17 GBytes  9.96 Gbits/sec    0',
        '[  6][TX-C]   0.00-1.00   sec  1.13 GBytes  9.65 Gbits/sec    1',
        '[SUM][TX-C]   0.00-1.00   sec  2.30 GBytes  19.6 Gbits/sec    1',
        '[  8][RX-C]   0.00-1.00   sec  1.11 GBytes  9.42 Gbits/sec',
        '[ 10][RX-C]   0.00-1.00   sec  1.10 GBytes  9.34 Gbits/sec',
        '[SUM][RX-C]   0.00-1.00   sec  2.20 GBytes  18.8 Gbits/sec',
      ];

      for (int i = 0; i < 5; i++) {
        expect(parser.parseLine(lines[i]), isNull);
      }

      final sample = parser.parseLine(lines[5]);
      expect(sample, isNotNull);
      // 19.6 Gbits/sec + 18.8 Gbits/sec = 38.4 Gbits/sec -> 38,400 Mbps
      expect(sample!.throughputMbps, closeTo(38400.0, 1.0));
      expect(sample.retransmits, equals(1));
      expect(sample.perStreamMbps.length, equals(4));
    });

    test('parses bidirectional summary lines and compiles correct aggregate metrics', () {
      const config = BenchmarkConfig(
        targetHost: '127.0.0.1',
        port: 5201,
        durationSeconds: 2,
        streams: 1,
        direction: 'bidirectional',
      );
      final parser = IPerfOutputParser(config: config);

      final logs = [
        'Connecting to host 127.0.0.1, port 5201',
        '[  4][TX-C]   0.00-1.00   sec  1.60 GBytes  13.7 Gbits/sec',
        '[  6][RX-C]   0.00-1.00   sec  1.59 GBytes  13.6 Gbits/sec',
        '[  4][TX-C]   1.00-2.00   sec  2.23 GBytes  19.2 Gbits/sec',
        '[  6][RX-C]   1.00-2.00   sec  2.16 GBytes  18.6 Gbits/sec',
        '- - - - - - - - - - - - - - - - - - - - - - - - -',
        '[  4][TX-C]   0.00-2.00   sec  3.83 GBytes  16.4 Gbits/sec                  sender',
        '[  4][TX-C]   0.00-2.00   sec  3.83 GBytes  16.4 Gbits/sec                  receiver',
        '[  6][RX-C]   0.00-2.00   sec  3.75 GBytes  16.1 Gbits/sec                  sender',
        '[  6][RX-C]   0.00-2.00   sec  3.75 GBytes  16.1 Gbits/sec                  receiver',
      ];

      for (final line in logs) {
        parser.parseLine(line);
      }

      final result = parser.compileResult(
        startTime: DateTime.now(),
        rawOutput: logs.join('\n'),
        status: 'completed',
      );

      // 16.4 Gbits/sec (TX) + 16.1 Gbits/sec (RX) = 32.5 Gbits/sec -> 32,500 Mbps
      expect(result.avgThroughputMbps, closeTo(32500.0, 1.0));
      expect(result.peakThroughputMbps, closeTo(37800.0, 1.0));
      expect(result.samples.length, equals(2));
      expect(result.status, equals('completed'));
    });

    test('parses line-delimited JSON stream event chunks (--json-stream)', () {
      const config = BenchmarkConfig(
        streams: 1,
        protocol: 'tcp',
        direction: 'bidirectional',
      );
      final parser = IPerfOutputParser(config: config);

      const jsonInterval = '{"event":"interval","data":{"streams":[{"socket":4,"bits_per_second":15592288943.63,"sender":true},{"socket":6,"bits_per_second":15550642052.03,"sender":false}],"sum":{"start":0,"end":1.007,"bytes":1963589632,"bits_per_second":15592288943.63,"retransmits":3,"sender":true},"sum_bidir_reverse":{"start":0,"end":1.007,"bytes":1958346752,"bits_per_second":15550656772.36,"retransmits":0,"sender":false}}}';
      final sample = parser.parseLine(jsonInterval);

      expect(sample, isNotNull);
      // (15.59 + 15.55) Gbps -> ~31,142 Mbps
      expect(sample!.throughputMbps, closeTo(31142.9, 1.0));
      expect(sample.retransmits, equals(3));
      expect(sample.perStreamMbps.length, equals(2));
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
