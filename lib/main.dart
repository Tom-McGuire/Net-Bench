import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/benchmark_repository.dart';
import 'domain/models/launch_adapter_config.dart';
import 'ui/theme/app_theme.dart';
import 'ui/view_models/benchmark_view_model.dart';
import 'ui/view_models/server_view_model.dart';
import 'ui/views/home_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final launchAdapterConfig = LaunchAdapterConfig.fromArgs(args);
  final repository = BenchmarkRepository();

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

class NetBenchApp extends StatelessWidget {
  const NetBenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Net-Bench • Local Network Benchmarker & iPerf3 Station',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
