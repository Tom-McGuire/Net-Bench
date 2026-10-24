import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:net_bench/data/repositories/benchmark_repository.dart';
import 'package:net_bench/data/services/database/benchmark_database_service.dart';
import 'package:net_bench/main.dart';
import 'package:net_bench/ui/view_models/benchmark_view_model.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';

void main() {
  testWidgets('NetBenchApp renders top control bar, tabs, and preset chips',
      (WidgetTester tester) async {
    // Configure standard desktop viewport dimensions (1280x800)
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final inMemoryDb = sqlite3.openInMemory();
    final dbService = BenchmarkDatabaseService(db: inMemoryDb);
    final repository = BenchmarkRepository(dbService: dbService);

    await tester.pumpWidget(
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

    // Initial pump and settling
    await tester.pump();

    // Verify Brand title & workspace tabs
    expect(find.text('NET-BENCH'), findsOneWidget);
    expect(find.text('LIVE BENCHMARK'), findsOneWidget);
    expect(find.text('SERVER DAEMON'), findsOneWidget);

    // Verify preset chips are present
    expect(find.text('1G Full-Duplex'), findsWidgets);
    expect(find.text('UDP Jitter Check'), findsOneWidget);
    expect(find.text('Bufferbloat Test'), findsOneWidget);

    // Verify Action button
    expect(find.text('START TEST'), findsOneWidget);

    // Clean up
    repository.dispose();
  });
}
