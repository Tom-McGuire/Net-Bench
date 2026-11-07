import 'package:flutter_test/flutter_test.dart';
import 'package:net_bench/data/services/ping/bufferbloat_ping_service.dart';

void main() {
  group('BufferbloatPingService Tests', () {
    late BufferbloatPingService pingService;

    setUp(() {
      pingService = BufferbloatPingService();
    });

    test('measurePing rejects empty strings and malicious flag arguments', () async {
      expect(await pingService.measurePing(''), isNull);
      expect(await pingService.measurePing('   '), isNull);
      expect(await pingService.measurePing('-c 1 8.8.8.8'), isNull);
      expect(await pingService.measurePing('-n 1 127.0.0.1'), isNull);
    });

    test('ping regex extracts round-trip times across OS stdout patterns', () {
      final regex = RegExp(
        r'time(?:=|<)?\s*([\d\.]+)\s*ms',
        caseSensitive: false,
      );

      // Linux / macOS ping output
      final linuxOutput = '64 bytes from 1.1.1.1: icmp_seq=1 ttl=57 time=14.2 ms';
      final matchLinux = regex.firstMatch(linuxOutput);
      expect(matchLinux, isNotNull);
      expect(double.tryParse(matchLinux!.group(1)!), equals(14.2));

      // macOS sub-millisecond output
      final macOutput = '64 bytes from 127.0.0.1: icmp_seq=0 ttl=64 time=0.085 ms';
      final matchMac = regex.firstMatch(macOutput);
      expect(matchMac, isNotNull);
      expect(double.tryParse(matchMac!.group(1)!), equals(0.085));

      // Windows standard output
      final winOutput = 'Reply from 8.8.8.8: bytes=32 time=23ms TTL=117';
      final matchWin = regex.firstMatch(winOutput);
      expect(matchWin, isNotNull);
      expect(double.tryParse(matchWin!.group(1)!), equals(23.0));

      // Windows sub-millisecond output
      final winSubMs = 'Reply from 192.168.1.1: bytes=32 time<1ms TTL=64';
      final matchWinSub = regex.firstMatch(winSubMs);
      expect(matchWinSub, isNotNull);
      expect(double.tryParse(matchWinSub!.group(1)!), equals(1.0));

      // Non-matching outputs (timeouts / unreachable)
      expect(regex.firstMatch('Request timed out.'), isNull);
      expect(regex.firstMatch('Destination Host Unreachable'), isNull);
      expect(regex.firstMatch('100% packet loss'), isNull);
    });
  });
}
