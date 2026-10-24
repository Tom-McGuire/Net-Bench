import 'benchmark_config.dart';

class BenchmarkPreset {
  const BenchmarkPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.config,
    required this.iconName,
    this.isBufferbloatPreset = false,
  });

  final String id;
  final String name;
  final String description;
  final BenchmarkConfig config;
  final String iconName;
  final bool isBufferbloatPreset;

  static List<BenchmarkPreset> defaultPresets = [
    const BenchmarkPreset(
      id: '1g_full_duplex',
      name: '1G Full-Duplex',
      description: '8 parallel TCP streams, bidirectional saturation test',
      iconName: 'sync_alt',
      config: BenchmarkConfig(
        protocol: 'tcp',
        direction: 'bidirectional',
        streams: 8,
        durationSeconds: 10,
        intervalSeconds: 1.0,
        profileName: '1G Full-Duplex',
      ),
    ),
    const BenchmarkPreset(
      id: 'udp_jitter_loss',
      name: 'UDP Jitter Check',
      description: '100 Mbps UDP stream measuring packet loss and jitter',
      iconName: 'speed',
      config: BenchmarkConfig(
        protocol: 'udp',
        direction: 'upload',
        streams: 1,
        durationSeconds: 10,
        udpBandwidthMbps: 100,
        intervalSeconds: 1.0,
        profileName: 'UDP Jitter Check',
      ),
    ),
    const BenchmarkPreset(
      id: 'bufferbloat_test',
      name: 'Bufferbloat Test',
      description: 'Saturates throughput while monitoring latency under load',
      iconName: 'hourglass_empty',
      isBufferbloatPreset: true,
      config: BenchmarkConfig(
        protocol: 'tcp',
        direction: 'upload',
        streams: 8,
        durationSeconds: 15,
        intervalSeconds: 1.0,
        profileName: 'Bufferbloat Test',
      ),
    ),
    const BenchmarkPreset(
      id: '10g_multistream',
      name: '10G Max Throughput',
      description: '16 streams, 1MB socket buffer for high-capacity links',
      iconName: 'bolt',
      config: BenchmarkConfig(
        protocol: 'tcp',
        direction: 'upload',
        streams: 16,
        durationSeconds: 20,
        socketBufferSizeKb: 1024,
        intervalSeconds: 1.0,
        profileName: '10G Max Throughput',
      ),
    ),
    const BenchmarkPreset(
      id: 'quick_5s',
      name: 'Quick 5s Health Check',
      description: 'Single-stream 5-second rapid connectivity baseline',
      iconName: 'flash_on',
      config: BenchmarkConfig(
        protocol: 'tcp',
        direction: 'upload',
        streams: 1,
        durationSeconds: 5,
        intervalSeconds: 1.0,
        profileName: 'Quick 5s Health Check',
      ),
    ),
  ];
}
