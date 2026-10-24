import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/services/iperf/iperf_mock_service.dart';
import 'package:net_bench/domain/models/benchmark_config.dart';
import 'package:net_bench/domain/models/live_sample.dart';

void main() {
  test('Mock service streams live samples and completes result', () async {
    final mockService = IPerfMockService();
    const config = BenchmarkConfig(
      durationSeconds: 2,
      protocol: 'tcp',
      streams: 4,
      profileName: 'Fast Mock Test',
    );

    final List<LiveSample> samples = [];
    final sub = mockService.sampleStream.listen((s) {
      samples.add(s);
    });

    mockService.execute(config);

    final result = await mockService.resultFuture;
    await sub.cancel();

    expect(samples.length, equals(2));
    expect(result.status, equals('completed'));
    expect(result.durationSeconds, equals(2));
    expect(result.avgThroughputMbps, greaterThan(500.0));
    expect(result.samples.length, equals(2));
  });

  test('Mock service can be canceled early', () async {
    final mockService = IPerfMockService();
    const config = BenchmarkConfig(
      durationSeconds: 10,
      protocol: 'tcp',
      streams: 2,
    );

    mockService.execute(config);
    mockService.cancel();

    final result = await mockService.resultFuture;
    expect(result.status, equals('aborted'));
  });
}
