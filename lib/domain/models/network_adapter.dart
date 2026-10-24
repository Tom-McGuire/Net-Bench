class NetworkAdapter {
  const NetworkAdapter({
    required this.name,
    required this.ipAddress,
    this.isLoopback = false,
  });

  final String name;
  final String ipAddress;
  final bool isLoopback;

  String get displayName {
    if (ipAddress == '0.0.0.0') {
      return 'All Interfaces (0.0.0.0)';
    }
    if (isLoopback || ipAddress == '127.0.0.1') {
      return 'Loopback (127.0.0.1)';
    }
    return '$name ($ipAddress)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkAdapter &&
          runtimeType == other.runtimeType &&
          ipAddress == other.ipAddress;

  @override
  int get hashCode => ipAddress.hashCode;

  @override
  String toString() => displayName;
}
