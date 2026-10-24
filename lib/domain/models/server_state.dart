class ServerState {
  const ServerState({
    this.isRunning = false,
    this.isSimulated = false,
    this.port = 5201,
    this.boundAddress = '0.0.0.0',
    this.oneOff = false,
    this.activeClients = const [],
    this.logs = const [],
    this.error,
    this.startedAt,
  });

  final bool isRunning;
  final bool isSimulated;
  final int port;
  final String boundAddress;
  final bool oneOff;
  final List<String> activeClients;
  final List<String> logs;
  final String? error;
  final DateTime? startedAt;

  ServerState copyWith({
    bool? isRunning,
    bool? isSimulated,
    int? port,
    String? boundAddress,
    bool? oneOff,
    List<String>? activeClients,
    List<String>? logs,
    String? error,
    DateTime? startedAt,
  }) {
    return ServerState(
      isRunning: isRunning ?? this.isRunning,
      isSimulated: isSimulated ?? this.isSimulated,
      port: port ?? this.port,
      boundAddress: boundAddress ?? this.boundAddress,
      oneOff: oneOff ?? this.oneOff,
      activeClients: activeClients ?? this.activeClients,
      logs: logs ?? this.logs,
      error: error,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}
