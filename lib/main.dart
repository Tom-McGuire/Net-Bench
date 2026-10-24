import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/benchmark_repository.dart';
import 'ui/theme/app_theme.dart';
import 'ui/view_models/benchmark_view_model.dart';
import 'ui/view_models/server_view_model.dart';
import 'ui/views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = BenchmarkRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BenchmarkViewModel(repository: repository),
        ),
        ChangeNotifierProvider(
          create: (_) => ServerViewModel(repository: repository),
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
