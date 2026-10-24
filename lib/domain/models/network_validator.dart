class NetworkValidator {
  static final RegExp _ipv4Regex = RegExp(
    r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );

  static final RegExp _hostnameRegex = RegExp(
    r'^(?![0-9]+$)(?!-)[a-zA-Z0-9-]{1,63}(?<!-)(?:\.(?!-)[a-zA-Z0-9-]{1,63}(?<!-))*$',
  );

  /// Validates an IPv4 or IPv6 address.
  static bool isValidIp(String? ip) {
    if (ip == null) return false;
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;

    if (_ipv4Regex.hasMatch(trimmed)) return true;

    // IPv6 check
    if (trimmed.contains(':') && !trimmed.contains(' ')) {
      try {
        final uri = Uri.parse('http://[$trimmed]');
        if (uri.host.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Validates an RFC-compliant hostname.
  static bool isValidHostname(String? hostname) {
    if (hostname == null) return false;
    final trimmed = hostname.trim();
    if (trimmed.isEmpty || trimmed.startsWith('-')) return false;
    if (trimmed.toLowerCase() == 'localhost') return true;
    return _hostnameRegex.hasMatch(trimmed);
  }

  /// Validates a target host or IP address.
  /// Rejects flags (starting with -), invalid characters, or out-of-spec hostnames.
  static bool isValidHost(String? host) {
    if (host == null) return false;
    final trimmed = host.trim();
    if (trimmed.isEmpty || trimmed.startsWith('-')) return false;

    if (isValidIp(trimmed)) return true;
    if (isValidHostname(trimmed)) return true;

    return false;
  }

  /// Validates port number (1 - 65535).
  static bool isValidPort(int? port) {
    if (port == null) return false;
    return port >= 1 && port <= 65535;
  }
}
