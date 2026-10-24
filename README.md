# Local Network Benchmarker & iPerf3 GUI (`net-bench`)

A modern, high-performance cross-platform Flutter desktop application (**Windows, macOS, and Linux**) designed for local network throughput testing, jitter/loss analysis, bufferbloat diagnosis, and comparative historical performance benchmarking using **iPerf3**.

---

## The Problem It Solves

`iperf3` is the gold standard for bandwidth throughput testing across network infrastructure, switches, access points, and hypervisors (UniFi, pfSense, OPNsense, TrueNAS, Proxmox). However, running tests via command-line arguments across repetitive test cycles makes comparing historical runs, isolating transient packet loss, and observing jitter/bufferbloat trends cumbersome.

**net-bench** provides an intuitive desktop control center that wraps both the **client** and **server daemon** workflows of `iperf3`, complete with:
- Subnet discovery for finding other benchmarker instances on the LAN.
- Real-time live gauge & area sparklines with micro-telemetry.
- Automated bufferbloat delta measurement ($RTT_{loaded} - RTT_{idle}$).
- Built-in test profile presets (1G Full-Duplex, UDP Jitter Check, Bufferbloat Test).
- Side-by-side historical runs comparison matrix with CSV & JSON exports.
- Fallback simulation mode and integrated multi-OS installation guide (`winget`, `choco`, `brew`, `apt`, `dnf`, `pacman`).

---

## Key Features

### 1. Integrated Client & Live Benchmark Workspace
- **Protocol Flexibility**: TCP throughput benchmarking and UDP jitter/packet loss analysis.
- **Multi-Stream & Bidirectional Modes**: Configure parallel worker threads (streams) and toggle normal, reverse (`-R`), or bidirectional modes.
- **Hardware Interface Binding**: List all physical & virtual network adapters on the host machine to bind tests to specific NICs (e.g. 10G SFP+, 2.5GbE, or Wi-Fi 6E).
- **Bufferbloat & Latency Under Load**: Pings the target host prior to saturation ($RTT_{idle}$) and during saturation ($RTT_{loaded}$) to calculate bufferbloat bloat delta.
- **Dynamic Live Telemetry**: Live throughput gauge, 60-sample area sparkline, instant bitrates, transfer totals, retries, jitter (ms), and lost datagrams.

### 2. Integrated Server Daemon Monitor
- **1-Click Local Server**: Launch an embedded `iperf3 -s` daemon directly from the UI to accept tests from remote clients or LAN nodes.
- **NIC Selection**: Bind the server listener to any network adapter or `0.0.0.0` (all interfaces).
- **Live Terminal Log**: Real-time console output displaying incoming connections, stream handshakes, and completion reports.
- **Clean Lifecycle & Port Cleanup**: Intercepts application window closing to gracefully terminate active server daemons and release listening ports.

### 3. Automatic Subnet Node Discovery
- **UDP Broadcast Beaconing**: Background discovery scanner broadcasts on UDP port `52010` to locate other active `net-bench` instances across the local subnet.
- **1-Click Target Selection**: Discovered nodes appear in a dedicated toolbar with hostnames and IP addresses for instant test targeting.

### 4. Historical Test Runs & Comparison Matrix
- **Local SQLite Storage**: Saves every benchmark run, telemetry samples, parameters, and raw JSON outputs locally via SQLite.
- **Comparative Diff Matrix**: Select multiple historical runs from the data table to display a side-by-side comparison matrix with delta highlighting (Best Bitrate, Min Jitter, Retransmission deltas).
- **Report Exports**: Instant RFC-compliant CSV reports and complete JSON run manifests.

### 5. Multi-OS Installation Guide & Detection
- Built-in Help modal providing one-click copy commands for:
  - **Windows**: `winget install iperf3` or `choco install iperf3`
  - **macOS**: `brew install iperf3`
  - **Linux**: `apt install iperf3`, `dnf install iperf3`, or `pacman -S iperf3`
- Live binary detection with real-time "RE-CHECK" and fallback demo simulation mode when testing UI workflows without external dependencies.

---

## Building from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ recommended)
- Desktop development dependencies:
  - **Windows**: Visual Studio 2022 with "Desktop development with C++"
  - **macOS**: Xcode & Command Line Tools
  - **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
- `iperf3` (optional for live testing; demo mode is included out of the box)

### Run in Development
```bash
flutter pub get
flutter run -d windows    # Or macos / linux
```

### Run Tests
```bash
flutter test
```

### Build Production Binary
```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

---

## Design System

Styled to match the consistent dark UI design language of companion networking utilities (`net-services`, `igmp-tester`, `syslog-server`, `tshark-interface`):
- Background: `#141414` (Deep Charcoal)
- Card Surfaces: `#1E1E1E` / High: `#252526` / Highest: `#2D2D2D`
- Accents: Electric Blue `#2979FF` / Cyan `#00E5FF` / Emerald `#00E676`
- Typography: Roboto with JetBrains Mono / Consolas for network metrics and CLI syntax.
