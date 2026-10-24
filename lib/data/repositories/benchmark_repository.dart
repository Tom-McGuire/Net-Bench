import 'dart:async';
import '../../domain/models/benchmark_config.dart';
import '../../domain/models/benchmark_result.dart';
import '../../domain/models/discovered_node.dart';
import '../../domain/models/live_sample.dart';
import '../../domain/models/network_adapter.dart';
import '../../domain/models/server_state.dart';
import '../services/database/benchmark_database_service.dart';
import '../services/discovery/discovery_service.dart';
import '../services/export/export_service.dart';
import '../services/iperf/iperf_binary_service.dart';
import '../services/iperf/iperf_client_service.dart';
import '../services/iperf/iperf_mock_service.dart';
import '../services/iperf/iperf_server_service.dart';
import '../services/network/network_interface_service.dart';
import '../services/ping/bufferbloat_ping_service.dart';

class BenchmarkRepository {
  BenchmarkRepository({
    BenchmarkDatabaseService? dbService,
    IPerfBinaryService? binaryService,
    IPerfServerService? serverService,
    DiscoveryService? discoveryService,
    BufferbloatPingService? pingService,
    ExportService? exportService,
    NetworkInterfaceService? networkInterfaceService,
  })  : dbService = dbService ?? BenchmarkDatabaseService(),
        binaryService = binaryService ?? IPerfBinaryService(),
        serverService = serverService ?? IPerfServerService(),
        discoveryService = discoveryService ?? DiscoveryService(),
        pingService = pingService ?? BufferbloatPingService(),
        exportService = exportService ?? ExportService(),
        networkInterfaceService =
            networkInterfaceService ?? NetworkInterfaceService();

  final BenchmarkDatabaseService dbService;
  final IPerfBinaryService binaryService;
  final IPerfServerService serverService;
  final DiscoveryService discoveryService;
  final BufferbloatPingService pingService;
  final ExportService exportService;
  final NetworkInterfaceService networkInterfaceService;

  IPerfClientService? _activeClient;
  IPerfMockService? _activeMock;
  IPerfBinaryInfo _binaryInfo = const IPerfBinaryInfo(isAvailable: false);

  IPerfBinaryInfo get binaryInfo => _binaryInfo;

  /// Initializes database, discovers binaries, and prepares repository.
  Future<void> init() async {
    await dbService.init();
    await serverService.cleanupOrphanServer();
    await checkBinary();
  }

  Future<IPerfBinaryInfo> checkBinary({String? customPath}) async {
    final svc = IPerfBinaryService(customPath: customPath);
    _binaryInfo = await svc.findBinary();
    return _binaryInfo;
  }

  /// Executes benchmark run either via native iPerf3 or via Mock engine (if in demo mode or binary missing).
  Stream<LiveSample> runBenchmark({
    required BenchmarkConfig config,
    required Function(BenchmarkResult) onComplete,
    bool forceDemo = false,
  }) {
    final useDemo = forceDemo || config.isDemoMode || !_binaryInfo.isAvailable;

    if (useDemo) {
      _activeMock = IPerfMockService();
      _activeMock!.execute(config);

      _activeMock!.resultFuture.then((res) {
        try {
          dbService.saveResult(res);
        } catch (_) {}
        onComplete(res);
        _activeMock = null;
      });

      return _activeMock!.sampleStream;
    } else {
      _activeClient = IPerfClientService();
      _activeClient!.execute(_binaryInfo.path!, config);

      _activeClient!.resultFuture.then((res) {
        try {
          dbService.saveResult(res);
        } catch (_) {}
        onComplete(res);
        _activeClient = null;
      });

      return _activeClient!.sampleStream;
    }
  }

  void cancelActiveBenchmark() {
    _activeClient?.cancel();
    _activeMock?.cancel();
    _activeClient = null;
    _activeMock = null;
  }

  // Server management
  Future<bool> startServer({
    int port = 5201,
    String bindAddress = '0.0.0.0',
    bool oneOff = false,
    bool? forceDemo,
  }) async {
    final useDemo = (forceDemo ?? false) || !_binaryInfo.isAvailable;

    if (useDemo) {
      return serverService.startSimulatedServer(
        port: port,
        bindAddress: bindAddress,
        oneOff: oneOff,
      );
    }

    return serverService.startServer(
      binaryPath: _binaryInfo.path!,
      port: port,
      bindAddress: bindAddress,
      oneOff: oneOff,
    );
  }

  Future<void> stopServer() async {
    await serverService.stopServer();
  }

  Stream<ServerState> get serverStateStream => serverService.stateStream;
  ServerState get currentServerState => serverService.currentState;

  // Network Adapters
  Future<List<NetworkAdapter>> getNetworkAdapters() =>
      networkInterfaceService.getAvailableAdapters();

  // Discovery
  Future<List<DiscoveredNode>> scanSubnet({int port = 5201}) {
    return discoveryService.scanSubnet(port: port);
  }

  Stream<List<DiscoveredNode>> get discoveredNodesStream =>
      discoveryService.nodesStream;
  List<DiscoveredNode> get currentDiscoveredNodes =>
      discoveryService.currentNodes;

  // History & Storage
  List<BenchmarkResult> getHistoricalRuns({
    int limit = 100,
    int offset = 0,
    String? searchQuery,
    String? protocol,
  }) {
    return dbService.getRuns(
      limit: limit,
      offset: offset,
      searchQuery: searchQuery,
      protocol: protocol,
    );
  }

  void deleteRun(String id) => dbService.deleteRun(id);
  void clearHistory() => dbService.clearAllRuns();
  int getTotalRunCount() => dbService.getRunCount();

  // Export
  Future<String?> exportCsv(BenchmarkResult result) =>
      exportService.exportCsvWithDialog(result);
  Future<String?> exportJson(BenchmarkResult result) =>
      exportService.exportJsonWithDialog(result);

  void dispose() {
    cancelActiveBenchmark();
    serverService.dispose();
    discoveryService.dispose();
    dbService.dispose();
  }
}
