import 'dart:io';
import 'package:path/path.dart' as p;

class IPerfBinaryInfo {
  const IPerfBinaryInfo({
    required this.isAvailable,
    this.path,
    this.version,
    this.parsedMajor = 0,
    this.parsedMinor = 0,
    this.parsedPatch = 0,
    this.isCustom = false,
  });

  final bool isAvailable;
  final String? path;
  final String? version;
  final int parsedMajor;
  final int parsedMinor;
  final int parsedPatch;
  final bool isCustom;

  /// Returns true if the version is older than 3.19.1 (which patched CVE-2023-38403 and server-side flaws)
  bool get isOlderThan3191 {
    if (!isAvailable || parsedMajor == 0) return false;
    if (parsedMajor < 3) return true;
    if (parsedMajor > 3) return false;
    if (parsedMinor < 19) return true;
    if (parsedMinor > 19) return false;
    return parsedPatch < 1;
  }

  /// Returns whether this iPerf3 version supports --json-stream (3.17+)
  bool get supportsJsonStream {
    if (!isAvailable || parsedMajor == 0) return false;
    if (parsedMajor > 3) return true;
    if (parsedMajor == 3 && parsedMinor >= 17) return true;
    return false;
  }
}

class IPerfBinaryService {
  IPerfBinaryService({this.customPath});

  final String? customPath;

  /// Attempts to locate the `iperf3` executable.
  Future<IPerfBinaryInfo> findBinary() async {
    // 1. Check custom user path if supplied
    if (customPath != null && customPath!.trim().isNotEmpty) {
      final f = File(customPath!.trim());
      if (await f.exists()) {
        final ver = await getVersion(f.path);
        final semver = _parseSemver(ver);
        return IPerfBinaryInfo(
          isAvailable: true,
          path: f.path,
          version: ver,
          parsedMajor: semver[0],
          parsedMinor: semver[1],
          parsedPatch: semver[2],
          isCustom: true,
        );
      }
    }

    // 2. Check standard platform locations (Program Files only on Windows to prevent C:\ root binary planting)
    if (Platform.isWindows) {
      final progFiles = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final progFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';

      final candidates = [
        p.join(progFiles, 'iperf3', 'iperf3.exe'),
        p.join(progFilesX86, 'iperf3', 'iperf3.exe'),
        p.join(progFiles, 'Wireshark', 'iperf3.exe'),
      ];

      for (final cand in candidates) {
        if (await File(cand).exists()) {
          final ver = await getVersion(cand);
          final semver = _parseSemver(ver);
          return IPerfBinaryInfo(
            isAvailable: true,
            path: cand,
            version: ver,
            parsedMajor: semver[0],
            parsedMinor: semver[1],
            parsedPatch: semver[2],
          );
        }
      }

      // Query via %SystemRoot%\System32\where.exe
      try {
        final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
        final whereExe = p.join(systemRoot, 'System32', 'where.exe');
        final whereCmd = await File(whereExe).exists() ? whereExe : 'where';

        final res = await Process.run(whereCmd, ['iperf3']);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final first = res.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first;
          if (await File(first).exists()) {
            final ver = await getVersion(first);
            final semver = _parseSemver(ver);
            return IPerfBinaryInfo(
              isAvailable: true,
              path: first,
              version: ver,
              parsedMajor: semver[0],
              parsedMinor: semver[1],
              parsedPatch: semver[2],
            );
          }
        }
      } catch (_) {}
    } else {
      // macOS & Linux
      final candidates = [
        '/opt/homebrew/bin/iperf3',
        '/usr/local/bin/iperf3',
        '/usr/bin/iperf3',
        '/bin/iperf3',
      ];

      for (final cand in candidates) {
        if (await File(cand).exists()) {
          final ver = await getVersion(cand);
          final semver = _parseSemver(ver);
          return IPerfBinaryInfo(
            isAvailable: true,
            path: cand,
            version: ver,
            parsedMajor: semver[0],
            parsedMinor: semver[1],
            parsedPatch: semver[2],
          );
        }
      }

      try {
        final whichCmd = await File('/usr/bin/which').exists() ? '/usr/bin/which' : 'which';
        final res = await Process.run(whichCmd, ['iperf3']);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final first = res.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first;
          if (await File(first).exists()) {
            final ver = await getVersion(first);
            final semver = _parseSemver(ver);
            return IPerfBinaryInfo(
              isAvailable: true,
              path: first,
              version: ver,
              parsedMajor: semver[0],
              parsedMinor: semver[1],
              parsedPatch: semver[2],
            );
          }
        }
      } catch (_) {}
    }

    return const IPerfBinaryInfo(isAvailable: false);
  }

  /// Runs `iperf3 -v` to fetch version string
  Future<String?> getVersion(String binaryPath) async {
    try {
      final res = await Process.run(binaryPath, ['-v']);
      if (res.exitCode == 0) {
        final line = res.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first;
        return line;
      }
    } catch (_) {}
    return null;
  }

  static List<int> _parseSemver(String? verStr) {
    if (verStr == null) return [0, 0, 0];
    final match = RegExp(r'iperf\s+(\d+)\.(\d+)(?:\.(\d+))?', caseSensitive: false)
        .firstMatch(verStr);
    if (match != null) {
      final maj = int.tryParse(match.group(1) ?? '') ?? 0;
      final min = int.tryParse(match.group(2) ?? '') ?? 0;
      final patch = int.tryParse(match.group(3) ?? '') ?? 0;
      return [maj, min, patch];
    }
    return [0, 0, 0];
  }
}
