import 'dart:io';
import 'package:path/path.dart' as p;

class BufferbloatPingService {
  // Regex to extract ping round-trip time in milliseconds
  static final RegExp _pingRegex = RegExp(
    r'time(?:=|<)?\s*([\d\.]+)\s*ms',
    caseSensitive: false,
  );

  /// Measures a single ping RTT to the specified target.
  Future<double?> measurePing(String host) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty || cleanHost.startsWith('-')) return null;

    try {
      final isWin = Platform.isWindows;
      String cmd = 'ping';
      if (isWin) {
        final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
        final pingExe = p.join(systemRoot, 'System32', 'PING.EXE');
        if (await File(pingExe).exists()) {
          cmd = pingExe;
        }
      }

      final args = isWin
          ? ['-n', '1', '-w', '1000', cleanHost]
          : ['-c', '1', '-W', '1', cleanHost];

      final res = await Process.run(cmd, args);
      if (res.exitCode == 0) {
        final match = _pingRegex.firstMatch(res.stdout.toString());
        if (match != null) {
          final ms = double.tryParse(match.group(1) ?? '');
          return ms;
        }
      }
    } catch (_) {}

    // Fallback: TCP connect latency probe if ICMP is blocked
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        cleanHost,
        80,
        timeout: const Duration(milliseconds: 1000),
      );
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds.toDouble();
    } catch (_) {}

    return null;
  }
}
