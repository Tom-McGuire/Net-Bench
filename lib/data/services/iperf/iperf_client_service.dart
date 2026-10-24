import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:net_bench/data/services/ping/bufferbloat_ping_service.dart';
import 'package:net_bench/domain/models/benchmark_config.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/domain/models/live_sample.dart';
import 'iperf_output_parser.dart';

class IPerfClientService {
  Process? _process;
  bool _isCanceled = false;

  final StreamController<LiveSample> _sampleController =
      StreamController<LiveSample>.broadcast();
  final Completer<BenchmarkResult> _resultCompleter =
      Completer<BenchmarkResult>();

  Stream<LiveSample> get sampleStream => _sampleController.stream;
  Future<BenchmarkResult> get resultFuture => _resultCompleter.future;

  /// Runs the iPerf3 client executable and streams interval samples.
  Future<void> execute(
    String binaryPath,
    BenchmarkConfig config, {
    bool supportsJsonStream = false,
    BufferbloatPingService? pingService,
  }) async {
    _isCanceled = false;
    final StringBuffer rawOutputBuffer = StringBuffer();
    final DateTime startTime = DateTime.now();

    final parser = IPerfOutputParser(config: config);

    // Baseline ping measurement if bufferbloat preset
    double? baselinePing;
    if (pingService != null) {
      baselinePing = await pingService.measurePing(config.targetHost);
    }

    // Build arguments from single source of truth
    final args = config.toCliArguments(
      useJsonStream: supportsJsonStream,
      forceFlush: true,
    );

    try {
      _process = await Process.start(binaryPath, args);

      final stdoutCompleter = Completer<void>();
      final stderrCompleter = Completer<void>();

      // Listen to stdout line by line
      final stdoutSub = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) async {
          rawOutputBuffer.writeln(line);

          final sample = parser.parseLine(line);
          if (sample != null) {
            // Optional loaded ping probe during run
            double? loadedPing;
            if (pingService != null && _collectedSampleIndex % 2 == 0) {
              loadedPing = await pingService.measurePing(config.targetHost);
            }

            final enrichedSample = loadedPing != null
                ? LiveSample(
                    interval: sample.interval,
                    secondsElapsed: sample.secondsElapsed,
                    throughputMbps: sample.throughputMbps,
                    perStreamMbps: sample.perStreamMbps,
                    retransmits: sample.retransmits,
                    jitterMs: sample.jitterMs,
                    lostPercent: sample.lostPercent,
                    lostPackets: sample.lostPackets,
                    totalPackets: sample.totalPackets,
                    pingRttMs: loadedPing,
                  )
                : sample;

            if (!_sampleController.isClosed) {
              _sampleController.add(enrichedSample);
            }
          }
        },
        onDone: () => stdoutCompleter.complete(),
        onError: (_) => stdoutCompleter.complete(),
      );

      // Listen to stderr
      final stderrSub = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (errLine) {
          rawOutputBuffer.writeln('[STDERR] $errLine');
        },
        onDone: () => stderrCompleter.complete(),
        onError: (_) => stderrCompleter.complete(),
      );

      // Wait for process exit AND stream completion so no trailing output is lost (B4)
      final exitCode = await _process!.exitCode;
      await Future.wait([stdoutCompleter.future, stderrCompleter.future]);
      await stdoutSub.cancel();
      await stderrSub.cancel();

      if (_isCanceled) {
        _finishAborted(parser, rawOutputBuffer.toString(), startTime);
        return;
      }

      if (exitCode != 0 && parser.collectedSamples.isEmpty) {
        _finishFailed(
          'iPerf3 process exited with code $exitCode: ${rawOutputBuffer.toString().trim()}',
          config,
          startTime,
          rawOutputBuffer.toString(),
        );
        return;
      }

      // Compile final result
      final result = parser.compileResult(
        startTime: startTime,
        rawOutput: rawOutputBuffer.toString(),
        status: 'completed',
        baselinePingMs: baselinePing,
      );

      if (!_resultCompleter.isCompleted) {
        _resultCompleter.complete(result);
      }
    } catch (e) {
      if (!_resultCompleter.isCompleted) {
        _finishFailed(
          'Failed to execute iPerf3: $e',
          config,
          startTime,
          rawOutputBuffer.toString(),
        );
      }
    } finally {
      if (!_sampleController.isClosed) {
        _sampleController.close();
      }
    }
  }

  int get _collectedSampleIndex => _process != null ? 1 : 0;

  void _finishAborted(
    IPerfOutputParser parser,
    String rawOutput,
    DateTime startTime,
  ) {
    if (!_resultCompleter.isCompleted) {
      final result = parser.compileResult(
        startTime: startTime,
        rawOutput: rawOutput,
        status: 'aborted',
        errorMessage: 'User stopped benchmark.',
      );
      _resultCompleter.complete(result);
    }
    if (!_sampleController.isClosed) {
      _sampleController.close();
    }
  }

  void _finishFailed(
    String error,
    BenchmarkConfig config,
    DateTime startTime,
    String rawOutput,
  ) {
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.complete(
        BenchmarkResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: startTime,
          profileName: config.profileName,
          targetHost: config.targetHost,
          port: config.port,
          protocol: config.protocol,
          direction: config.direction,
          streams: config.streams,
          durationSeconds: config.durationSeconds,
          avgThroughputMbps: 0.0,
          peakThroughputMbps: 0.0,
          minThroughputMbps: 0.0,
          totalBytes: 0,
          rawJson: rawOutput,
          status: 'failed',
          errorMessage: error,
        ),
      );
    }
  }

  void cancel() {
    _isCanceled = true;
    _process?.kill(ProcessSignal.sigterm);
    Future.delayed(const Duration(milliseconds: 300), () {
      _process?.kill(ProcessSignal.sigkill);
    });
  }
}
