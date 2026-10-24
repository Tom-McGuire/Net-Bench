import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/services/export/export_service.dart';
import 'package:net_bench/data/services/iperf/iperf_binary_service.dart';
import 'package:net_bench/domain/models/network_validator.dart';

void main() {
  group('NetworkValidator Security & Format Validation', () {
    test('validates IPv4 addresses correctly', () {
      expect(NetworkValidator.isValidIp('192.168.1.1'), isTrue);
      expect(NetworkValidator.isValidIp('10.0.0.1'), isTrue);
      expect(NetworkValidator.isValidIp('127.0.0.1'), isTrue);
      expect(NetworkValidator.isValidIp('255.255.255.255'), isTrue);

      expect(NetworkValidator.isValidIp('256.0.0.1'), isFalse);
      expect(NetworkValidator.isValidIp('192.168.1'), isFalse);
      expect(NetworkValidator.isValidIp('192.168.1.1.1'), isFalse);
      expect(NetworkValidator.isValidIp('192.168.1.a'), isFalse);
    });

    test('validates IPv6 addresses correctly', () {
      expect(NetworkValidator.isValidIp('::1'), isTrue);
      expect(NetworkValidator.isValidIp('2001:db8::1'), isTrue);
      expect(NetworkValidator.isValidIp('fe80::1ff:fe23:4567:890a'), isTrue);

      expect(NetworkValidator.isValidIp(':::'), isFalse);
      expect(NetworkValidator.isValidIp('1200::ABXX:0012'), isFalse);
    });

    test('validates RFC-compliant hostnames and rejects injection flags', () {
      expect(NetworkValidator.isValidHostname('localhost'), isTrue);
      expect(NetworkValidator.isValidHostname('iperf.he.net'), isTrue);
      expect(NetworkValidator.isValidHostname('my-router.lan'), isTrue);
      expect(NetworkValidator.isValidHostname('server-01.corp.internal'), isTrue);

      // Malicious or command-injection strings
      expect(NetworkValidator.isValidHostname('-u'), isFalse);
      expect(NetworkValidator.isValidHostname('--bind'), isFalse);
      expect(NetworkValidator.isValidHostname('host; rm -rf /'), isFalse);
      expect(NetworkValidator.isValidHostname('host | calc.exe'), isFalse);
      expect(NetworkValidator.isValidHostname('host`id`'), isFalse);
      expect(NetworkValidator.isValidHostname('host\$(whoami)'), isFalse);
      expect(NetworkValidator.isValidHostname(''), isFalse);
    });

    test('validates port range bounds (1-65535)', () {
      expect(NetworkValidator.isValidPort(1), isTrue);
      expect(NetworkValidator.isValidPort(80), isTrue);
      expect(NetworkValidator.isValidPort(5201), isTrue);
      expect(NetworkValidator.isValidPort(65535), isTrue);

      expect(NetworkValidator.isValidPort(0), isFalse);
      expect(NetworkValidator.isValidPort(-1), isFalse);
      expect(NetworkValidator.isValidPort(65536), isFalse);
      expect(NetworkValidator.isValidPort(99999), isFalse);
    });

    test('isValidHost combines IP and hostname rules safely', () {
      expect(NetworkValidator.isValidHost('192.168.1.100'), isTrue);
      expect(NetworkValidator.isValidHost('speedtest.local'), isTrue);
      expect(NetworkValidator.isValidHost('-c 192.168.1.1'), isFalse);
      expect(NetworkValidator.isValidHost('; taskkill /f'), isFalse);
    });
  });

  group('ExportService Security Sanitization', () {
    test('escapes formula injection cells starting with =, +, -, @, tab, CR', () {
      expect(ExportService.sanitizeCsvCell('=1+1'), equals("'=1+1"));
      expect(ExportService.sanitizeCsvCell('+cmd|/c calc'), equals("'+cmd|/c calc"));
      expect(ExportService.sanitizeCsvCell('-2+5'), equals("'-2+5"));
      expect(ExportService.sanitizeCsvCell('@SUM(A1:A10)'), equals("'@SUM(A1:A10)"));
      expect(ExportService.sanitizeCsvCell('\tmalicious'), equals("'\tmalicious"));
      expect(ExportService.sanitizeCsvCell('\rmalicious'), equals("'\rmalicious"));

      // Normal benign values must remain unaffected
      expect(ExportService.sanitizeCsvCell('192.168.1.1'), equals('192.168.1.1'));
      expect(ExportService.sanitizeCsvCell('941.50'), equals('941.50'));
      expect(ExportService.sanitizeCsvCell('TCP'), equals('TCP'));
    });

    test('sanitizes illegal file path characters in generated filenames', () {
      expect(ExportService.sanitizeFileName('netbench:test*file?.csv'), equals('netbench_test_file_.csv'));
      expect(ExportService.sanitizeFileName('run/2026\\01"|<>'), equals('run_2026_01____'));
    });
  });

  group('IPerfBinaryInfo Version Vulnerability Check', () {
    test('correctly flags versions older than 3.19.1', () {
      const v37 = IPerfBinaryInfo(
        isAvailable: true,
        path: 'iperf3.exe',
        version: 'iperf 3.7 (cJSON 1.5.2)',
        parsedMajor: 3,
        parsedMinor: 7,
        parsedPatch: 0,
      );
      expect(v37.isOlderThan3191, isTrue);

      const v3190 = IPerfBinaryInfo(
        isAvailable: true,
        path: 'iperf3.exe',
        version: 'iperf 3.19.0',
        parsedMajor: 3,
        parsedMinor: 19,
        parsedPatch: 0,
      );
      expect(v3190.isOlderThan3191, isTrue);

      const v3191 = IPerfBinaryInfo(
        isAvailable: true,
        path: 'iperf3.exe',
        version: 'iperf 3.19.1',
        parsedMajor: 3,
        parsedMinor: 19,
        parsedPatch: 1,
      );
      expect(v3191.isOlderThan3191, isFalse);

      const v320 = IPerfBinaryInfo(
        isAvailable: true,
        path: 'iperf3.exe',
        version: 'iperf 3.20.0',
        parsedMajor: 3,
        parsedMinor: 20,
        parsedPatch: 0,
      );
      expect(v320.isOlderThan3191, isFalse);
    });
  });
}
