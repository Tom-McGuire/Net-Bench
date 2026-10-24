import 'dart:async';
import 'dart:math';
import '../../../domain/models/benchmark_config.dart';
import '../../../domain/models/benchmark_result.dart';
import '../../../domain/models/live_sample.dart';

class IPerfMockService {
  Timer? _timer;
  bool _isCanceled = false;

  final StreamController<LiveSample> _sampleController =
      StreamController<LiveSample>.broadcast();
  final Completer<BenchmarkResult> _resultCompleter =
      Completer<BenchmarkResult>();

  Stream<LiveSample> get sampleStream => _sampleController.stream;
  Future<BenchmarkResult> get resultFuture => _resultCompleter.future;

  void execute(BenchmarkConfig config) {
    _isCanceled = false;
    final List<LiveSample> collectedSamples = [];
    final DateTime startTime = DateTime.now();
    final Random random = Random();

    int currentSecond = 0;
    final is10G = config.streams >= 16;
    final baseTargetMbps = config.isUdp
        ? config.udpBandwidthMbps.toDouble()
        : (is10G ? 9350.0 : 942.0);

    final baselinePing = 8.0 + random.nextDouble() * 4.0; // 8 - 12 ms

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCanceled) {
        timer.cancel();
        return;
      }

      currentSecond++;

      // Simulate ramp-up in first 2 seconds, then steady-state throughput
      double rampMultiplier = 1.0;
      if (currentSecond == 1) {
        rampMultiplier = 0.72 + (random.nextDouble() * 0.1);
      } else if (currentSecond == 2) {
        rampMultiplier = 0.91 + (random.nextDouble() * 0.05);
      } else {
        rampMultiplier = 0.97 + (random.nextDouble() * 0.05);
      }

      final throughput = double.parse(
          (baseTargetMbps * rampMultiplier).toStringAsFixed(1));

      // Stream breakdown
      final perStream = <int, double>{};
      final streamFraction = throughput / config.streams;
      for (int i = 1; i <= config.streams; i++) {
        final jitterFactor = 0.95 + (random.nextDouble() * 0.1);
        perStream[i] =
            double.parse((streamFraction * jitterFactor).toStringAsFixed(1));
      }

      final retransmits = config.isUdp
          ? 0
          : (random.nextDouble() < 0.25 ? random.nextInt(3) : 0);

      final jitterMs = config.isUdp
          ? double.parse((0.03 + random.nextDouble() * 0.45).toStringAsFixed(3))
          : null;

      final lostDatagrams = config.isUdp
          ? (random.nextDouble() < 0.2 ? random.nextInt(4) : 0)
          : null;
      final totalDatagrams = config.isUdp ? 8500 + random.nextInt(200) : null;
      final lossPercent = (config.isUdp && totalDatagrams != null)
          ? double.parse(
              ((lostDatagrams! / totalDatagrams) * 100).toStringAsFixed(2))
          : null;

      // Simulated bufferbloat loaded ping
      final loadedPing = baselinePing +
          (rampMultiplier * 35.0) +
          (random.nextDouble() * 20.0);

      final sample = LiveSample(
        interval: currentSecond,
        secondsElapsed: currentSecond.toDouble(),
        throughputMbps: throughput,
        perStreamMbps: perStream,
        retransmits: retransmits,
        jitterMs: jitterMs,
        lostPercent: lossPercent,
        lostPackets: lostDatagrams,
        totalPackets: totalDatagrams,
        pingRttMs: double.parse(loadedPing.toStringAsFixed(1)),
      );

      collectedSamples.add(sample);
      if (!_sampleController.isClosed) {
        _sampleController.add(sample);
      }

      if (currentSecond >= config.durationSeconds) {
        timer.cancel();
        _finishBenchmark(
          collectedSamples,
          config,
          startTime,
          baselinePing,
        );
      }
    });
  }

  void _finishBenchmark(
    List<LiveSample> samples,
    BenchmarkConfig config,
    DateTime startTime,
    double baselinePing,
  ) {
    double sum = 0.0;
    double peak = 0.0;
    double min = double.infinity;
    int totalRetr = 0;
    double? avgJitter;
    double? lastLoss;
    int? totalLost;
    int? totalPackets;
    double sumPing = 0.0;

    for (final s in samples) {
      sum += s.throughputMbps;
      if (s.throughputMbps > peak) peak = s.throughputMbps;
      if (s.throughputMbps < min) min = s.throughputMbps;
      totalRetr += s.retransmits;
      if (s.jitterMs != null) {
        avgJitter = (avgJitter == null) ? s.jitterMs : (avgJitter + s.jitterMs!) / 2;
      }
      if (s.lostPercent != null) lastLoss = s.lostPercent;
      if (s.lostPackets != null) totalLost = (totalLost ?? 0) + s.lostPackets!;
      if (s.totalPackets != null) {
        totalPackets = (totalPackets ?? 0) + s.totalPackets!;
      }
      if (s.pingRttMs != null) sumPing += s.pingRttMs!;
    }

    final avg = samples.isNotEmpty ? sum / samples.length : 0.0;
    if (min == double.infinity) min = 0.0;
    final avgLoadedPing = samples.isNotEmpty ? sumPing / samples.length : baselinePing;
    final bufferbloatDelta = avgLoadedPing - baselinePing;

    final approxBytes =
        ((avg * config.durationSeconds * 1000000) / 8).round();

    final result = BenchmarkResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: startTime,
      profileName: config.profileName,
      targetHost: config.targetHost,
      port: config.port,
      protocol: config.protocol,
      direction: config.direction,
      streams: config.streams,
      durationSeconds: config.durationSeconds,
      avgThroughputMbps: double.parse(avg.toStringAsFixed(2)),
      peakThroughputMbps: double.parse(peak.toStringAsFixed(2)),
      minThroughputMbps: double.parse(min.toStringAsFixed(2)),
      totalBytes: approxBytes,
      jitterMs: avgJitter != null
          ? double.parse(avgJitter.toStringAsFixed(3))
          : null,
      lossPercent: lastLoss,
      lostPackets: totalLost,
      totalPackets: totalPackets,
      retransmits: totalRetr,
      baselinePingMs: double.parse(baselinePing.toStringAsFixed(1)),
      loadedPingMs: double.parse(avgLoadedPing.toStringAsFixed(1)),
      bufferbloatDeltaMs: double.parse(bufferbloatDelta.toStringAsFixed(1)),
      samples: samples,
      rawJson: '{"mode":"demo_simulation","status":"success","samples":${samples.length}}',
      status: 'completed',
    );

    if (!_resultCompleter.isCompleted) {
      _resultCompleter.complete(result);
    }
    if (!_sampleController.isClosed) {
      _sampleController.close();
    }
  }

  void cancel() {
    _isCanceled = true;
    _timer?.cancel();
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.complete(
        BenchmarkResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          profileName: 'Canceled Test',
          targetHost: '',
          port: 5201,
          protocol: 'tcp',
          direction: 'upload',
          streams: 1,
          durationSeconds: 0,
          avgThroughputMbps: 0.0,
          peakThroughputMbps: 0.0,
          minThroughputMbps: 0.0,
          totalBytes: 0,
          status: 'aborted',
          errorMessage: 'Benchmark was canceled.',
        ),
      );
    }
    if (!_sampleController.isClosed) {
      _sampleController.close();
    }
  }
}
