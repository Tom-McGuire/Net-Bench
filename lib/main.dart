import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'data/repositories/benchmark_repository.dart';
import 'data/services/database/shared_device_database.dart';
import 'domain/models/launch_adapter_config.dart';
import 'ui/theme/app_theme.dart';
import 'ui/view_models/benchmark_view_model.dart';
import 'ui/view_models/server_view_model.dart';
import 'ui/views/home_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final launchAdapterConfig = LaunchAdapterConfig.fromArgs(args);
  final repository = BenchmarkRepository();
  final initialMode = await SharedDeviceDatabase.instance.getThemeMode();
  AppTheme.isDark = (initialMode == 'dark');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BenchmarkViewModel(
            repository: repository,
            initialAdapterConfig: launchAdapterConfig,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ServerViewModel(
            repository: repository,
            initialAdapterConfig: launchAdapterConfig,
          ),
        ),
      ],
      child: const NetBenchApp(),
    ),
  );
}

class NetBenchApp extends StatefulWidget {
  const NetBenchApp({super.key, this.sharedDatabase});

  final SharedDeviceDatabase? sharedDatabase;

  @override
  State<NetBenchApp> createState() => _NetBenchAppState();
}

class _NetBenchAppState extends State<NetBenchApp> {
  StreamSubscription<void>? _dbSub;
  String _themeMode = AppTheme.isDark ? 'dark' : 'light';

  SharedDeviceDatabase get _db =>
      widget.sharedDatabase ?? SharedDeviceDatabase.instance;

  @override
  void initState() {
    super.initState();
    _syncTheme();
    _dbSub = _db.onDatabaseChanged.listen((_) {
      _syncTheme();
    });
  }

  Future<void> _syncTheme() async {
    final mode = await _db.getThemeMode();
    if (!mounted) return;
    if (mode != _themeMode || (mode == 'dark') != AppTheme.isDark) {
      setState(() {
        _themeMode = mode;
        AppTheme.isDark = (mode == 'dark');
      });
    }
  }

  @override
  void dispose() {
    _dbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Net-Bench • Local Network Benchmarker & iPerf3 Station',
      debugShowCheckedModeBanner: false,
      themeMode: AppTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: KeyedSubtree(
        key: ValueKey(_themeMode),
        child: const HomeScreen(),
      ),
    );
  }
}
