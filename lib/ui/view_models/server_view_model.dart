import 'dart:async';
import 'package:flutter/material.dart';
import 'package:net_bench/data/repositories/benchmark_repository.dart';
import 'package:net_bench/domain/models/launch_adapter_config.dart';
import 'package:net_bench/domain/models/network_adapter.dart';
import 'package:net_bench/domain/models/server_state.dart';

class ServerViewModel extends ChangeNotifier {
  ServerViewModel({
    required this.repository,
    this.initialAdapterConfig,
  }) {
    _init();
  }

  final BenchmarkRepository repository;
  final LaunchAdapterConfig? initialAdapterConfig;
  bool _startupAdapterApplied = false;
  ServerState _state = const ServerState();
  StreamSubscription<ServerState>? _stateSub;

  int _port = 5201;
  String _bindAddress = '0.0.0.0';
  bool _oneOff = false;

  List<NetworkAdapter> _availableAdapters = const [
    NetworkAdapter(name: 'All Interfaces', ipAddress: '0.0.0.0'),
    NetworkAdapter(name: 'Loopback', ipAddress: '127.0.0.1', isLoopback: true),
  ];

  ServerState get state => _state;
  bool get isRunning => _state.isRunning;
  bool get isSimulated => _state.isSimulated;
  int get port => _port;
  String get bindAddress => _bindAddress;
  bool get oneOff => _oneOff;
  List<String> get logs => _state.logs;
  List<String> get activeClients => _state.activeClients;
  List<NetworkAdapter> get availableAdapters =>
      List.unmodifiable(_availableAdapters);

  void _init() {
    _state = repository.currentServerState;
    _stateSub = repository.serverStateStream.listen((newState) {
      _state = newState;
      notifyListeners();
    });
    loadAdapters();
  }

  Future<void> loadAdapters() async {
    final list = await repository.getNetworkAdapters();
    if (list.isNotEmpty) {
      _availableAdapters = list;
      if (!_startupAdapterApplied &&
          initialAdapterConfig != null &&
          initialAdapterConfig!.hasOverride) {
        _startupAdapterApplied = true;
        final matched = initialAdapterConfig!.matchAdapter(_availableAdapters);
        if (matched != null) {
          _bindAddress = matched.ipAddress;
        }
      }
      notifyListeners();
    }
  }

  void setPort(int newPort) {
    _port = newPort;
    notifyListeners();
  }

  void setBindAddress(String address) {
    _bindAddress = address;
    notifyListeners();
  }

  void setOneOff(bool value) {
    _oneOff = value;
    notifyListeners();
  }

  Future<bool> toggleServer({bool? forceDemo}) async {
    if (_state.isRunning) {
      await repository.stopServer();
      _state = repository.currentServerState;
      notifyListeners();
      return true;
    } else {
      final ok = await repository.startServer(
        port: _port,
        bindAddress: _bindAddress,
        oneOff: _oneOff,
        forceDemo: forceDemo,
      );
      _state = repository.currentServerState;
      notifyListeners();
      return ok;
    }
  }

  Future<void> stopServer() async {
    await repository.stopServer();
    _state = repository.currentServerState;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }
}
