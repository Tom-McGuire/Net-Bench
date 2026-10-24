import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../domain/models/server_state.dart';

class IPerfServerService {
  IPerfServerService({Directory? appSupportDirectory})
      : _customSupportDir = appSupportDirectory;

  final Directory? _customSupportDir;
  Process? _serverProcess;
  Timer? _simulatedTimer;
  final StreamController<ServerState> _stateController =
      StreamController<ServerState>.broadcast();

  ServerState _currentState = const ServerState();
  ServerState get currentState => _currentState;
  Stream<ServerState> get stateStream => _stateController.stream;

  static const String _pidFileName = 'iperf3_server.pid';

  // Regex to detect client connection from server output
  // e.g. "Accepted connection from 192.168.1.15, port 58922"
  static final RegExp _clientAcceptedRegex = RegExp(
    r'Accepted connection from ([^\s,]+)',
    caseSensitive: false,
  );

  Future<File?> _getPidFile() async {
    try {
      final dir = _customSupportDir ?? await getApplicationSupportDirectory();
      return File(p.join(dir.path, _pidFileName));
    } catch (_) {
      return null;
    }
  }

  /// Cleans up any orphaned iperf3 server daemon process from a previous abnormal termination.
  Future<void> cleanupOrphanServer() async {
    try {
      final pidFile = await _getPidFile();
      if (pidFile != null && await pidFile.exists()) {
        final content = await pidFile.readAsString();
        final pid = int.tryParse(content.trim());
        if (pid != null) {
          try {
            Process.killPid(pid);
          } catch (_) {}
        }
        await pidFile.delete();
      }
    } catch (_) {}
  }

  /// Starts the iperf3 server daemon in simulated / demo mode.
  Future<bool> startSimulatedServer({
    int port = 5201,
    String bindAddress = '0.0.0.0',
    bool oneOff = false,
  }) async {
    await stopServer();

    final logs = <String>[
      '[SIMULATED SERVER STARTED] Listening on $bindAddress:$port (Simulation Mode)',
      '[SERVER READY] Waiting for incoming client connections...',
    ];

    _currentState = ServerState(
      isRunning: true,
      isSimulated: true,
      port: port,
      boundAddress: bindAddress,
      oneOff: oneOff,
      startedAt: DateTime.now(),
      logs: List.unmodifiable(logs),
      error: null,
    );
    _emitState();

    int tick = 0;
    _simulatedTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_currentState.isRunning || !_currentState.isSimulated) {
        timer.cancel();
        return;
      }
      tick++;

      // Every 3rd tick simulate a client connection test run
      if (tick % 3 == 1) {
        logs.add('-----------------------------------------------------------');
        logs.add('Accepted connection from 192.168.1.105, port 53421');
        logs.add(
            '[  5] local $bindAddress port $port connected to 192.168.1.105 port 53421');
        logs.add('[ ID] Interval           Transfer     Bitrate');
        logs.add('[  5]   0.00-1.00   sec   112 MBytes   941 Mbits/sec');
        logs.add('[  5]   1.00-2.00   sec   113 MBytes   948 Mbits/sec');
        logs.add('[  5]   2.00-3.00   sec   112 MBytes   942 Mbits/sec');
        logs.add(
            '[  5]   0.00-3.00   sec   337 MBytes   944 Mbits/sec                  receiver');

        if (oneOff) {
          logs.add('[SERVER STOPPED] Handled one-off client test (-1), exiting.');
          _currentState = _currentState.copyWith(
            isRunning: false,
            logs: List.unmodifiable(logs),
            activeClients: const [],
          );
          timer.cancel();
          _emitState();
          return;
        } else {
          logs.add('[SERVER IDLE] Waiting for incoming client connections...');
        }
      }

      if (logs.length > 500) logs.removeRange(0, logs.length - 500);
      _currentState = _currentState.copyWith(
        logs: List.unmodifiable(logs),
        activeClients: (tick % 3 == 1) ? const ['192.168.1.105'] : const [],
      );
      _emitState();
    });

    return true;
  }

  /// Starts the native iperf3 server daemon on the given port.
  Future<bool> startServer({
    required String binaryPath,
    int port = 5201,
    String bindAddress = '0.0.0.0',
    bool oneOff = false,
  }) async {
    if (_serverProcess != null || _simulatedTimer != null) {
      await stopServer();
    } else {
      await cleanupOrphanServer();
    }

    final logs = <String>[];
    final activeClients = <String>[];

    final args = <String>['-s', '-p', port.toString()];
    if (bindAddress != '0.0.0.0' && bindAddress.isNotEmpty) {
      args.addAll(['-B', bindAddress]);
    }
    if (oneOff) {
      args.add('-1');
    }

    try {
      _serverProcess = await Process.start(binaryPath, args);
      final pid = _serverProcess!.pid;
      final pidFile = await _getPidFile();
      if (pidFile != null) {
        await pidFile.writeAsString(pid.toString());
      }

      _currentState = ServerState(
        isRunning: true,
        isSimulated: false,
        port: port,
        boundAddress: bindAddress,
        oneOff: oneOff,
        startedAt: DateTime.now(),
        logs: [
          '[SERVER STARTED] Listening on $bindAddress:$port${oneOff ? ' (one-off mode)' : ''}'
        ],
        error: null,
      );
      _emitState();

      // Listen for stdout
      _serverProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        logs.add(line);
        if (logs.length > 500) logs.removeAt(0);

        final match = _clientAcceptedRegex.firstMatch(line);
        if (match != null) {
          final clientIp = match.group(1);
          if (clientIp != null && !activeClients.contains(clientIp)) {
            activeClients.add(clientIp);
          }
        }

        _currentState = _currentState.copyWith(
          logs: List.unmodifiable(logs),
          activeClients: List.unmodifiable(activeClients),
        );
        _emitState();
      });

      // Listen for stderr
      _serverProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((errLine) {
        logs.add('[STDERR] $errLine');
        if (logs.length > 500) logs.removeAt(0);

        _currentState = _currentState.copyWith(
          logs: List.unmodifiable(logs),
        );
        _emitState();
      });

      // Monitor exit
      _serverProcess!.exitCode.then((code) async {
        if (code != 0) {
          logs.add(
              '[ERROR] Server process exited with code $code. Check if port $port is already in use.');
        } else {
          logs.add('[SERVER STOPPED] Process exited with code $code');
        }

        _currentState = _currentState.copyWith(
          isRunning: false,
          logs: List.unmodifiable(logs),
          activeClients: const [],
          error: code != 0
              ? 'Server process exited with code $code. Check log stream below.'
              : null,
        );
        _serverProcess = null;
        final pidFile = await _getPidFile();
        if (pidFile != null && await pidFile.exists()) {
          try {
            await pidFile.delete();
          } catch (_) {}
        }
        _emitState();
      });

      return true;
    } catch (e) {
      _currentState = _currentState.copyWith(
        isRunning: false,
        error: 'Failed to start iPerf3 server: $e',
        logs: ['[ERROR] Failed to start iPerf3 server process: $e'],
      );
      _emitState();
      return false;
    }
  }

  /// Stops the running server daemon (native or simulated).
  Future<void> stopServer() async {
    _simulatedTimer?.cancel();
    _simulatedTimer = null;

    if (_serverProcess != null) {
      _serverProcess!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 300));
      _serverProcess?.kill(ProcessSignal.sigkill);
      _serverProcess = null;
    }
    final pidFile = await _getPidFile();
    if (pidFile != null && await pidFile.exists()) {
      try {
        await pidFile.delete();
      } catch (_) {}
    }
    _currentState = _currentState.copyWith(
      isRunning: false,
      activeClients: const [],
      logs: [
        ..._currentState.logs,
        '[SERVER STOPPED] Server daemon stopped.',
      ],
    );
    _emitState();
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  void dispose() {
    stopServer();
    _stateController.close();
  }
}
