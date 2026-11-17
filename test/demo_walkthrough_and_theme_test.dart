import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:net_bench/data/repositories/benchmark_repository.dart';
import 'package:net_bench/data/services/database/benchmark_database_service.dart';
import 'package:net_bench/data/services/database/shared_device_database.dart';
import 'package:net_bench/main.dart';
import 'package:net_bench/ui/theme/app_theme.dart';
import 'package:net_bench/ui/view_models/benchmark_view_model.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';
import 'package:net_bench/ui/views/home_screen.dart';
import 'package:net_bench/ui/widgets/guided_tour_overlay.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  tearDown(() {
    AppTheme.isDark = true;
  });

  group('BenchmarkViewModel Demo Walkthrough Lifecycle & DB Isolation', () {
    late Database inMemoryDb;
    late BenchmarkDatabaseService dbService;
    late BenchmarkRepository repository;
    late BenchmarkViewModel viewModel;

    setUp(() async {
      inMemoryDb = sqlite3.openInMemory();
      dbService = BenchmarkDatabaseService(db: inMemoryDb);
      repository = BenchmarkRepository(dbService: dbService);
      viewModel = BenchmarkViewModel(repository: repository);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      viewModel.dispose();
      repository.dispose();
    });

    test('starts cleanly in idle mode without auto-enabling demo mode', () {
      expect(viewModel.isDemoMode, isFalse);
      expect(viewModel.isDemoWalkthroughActive, isFalse);
      expect(viewModel.liveSamples, isEmpty);
      expect(viewModel.historicalRuns, isEmpty);
      expect(viewModel.selectedInspectorRecord, isNull);
    });

    test(
        'startDemoWalkthrough populates telemetry without writing to SQLite and endDemoWalkthrough clears all demo state',
        () {
      viewModel.startDemoWalkthrough();

      expect(viewModel.isDemoMode, isTrue);
      expect(viewModel.isDemoWalkthroughActive, isTrue);
      expect(viewModel.config.targetHost, equals('192.168.1.10'));
      expect(viewModel.config.port, equals(5201));

      expect(viewModel.liveSamples.length, equals(10));
      expect(viewModel.currentSample, isNotNull);
      expect(viewModel.historicalRuns.length, equals(2));
      expect(
        viewModel.historicalRuns.map((r) => r.id),
        containsAll(['demo-run-1', 'demo-run-2']),
      );
      expect(viewModel.comparisonRuns.length, equals(2));
      expect(viewModel.selectedInspectorRecord?.id, equals('demo-run-1'));
      expect(viewModel.discoveredNodes.length, equals(2));

      // Strict DB isolation: SQLite test_runs must remain untouched.
      expect(dbService.getRuns(), isEmpty);
      expect(dbService.getRunCount(), equals(0));

      viewModel.endDemoWalkthrough();

      expect(viewModel.isDemoMode, isFalse);
      expect(viewModel.isDemoWalkthroughActive, isFalse);
      expect(viewModel.liveSamples, isEmpty);
      expect(viewModel.currentSample, isNull);
      expect(viewModel.lastCompletedResult, isNull);
      expect(viewModel.historicalRuns, isEmpty);
      expect(viewModel.comparisonRuns, isEmpty);
      expect(viewModel.selectedComparisonIds, isEmpty);
      expect(viewModel.selectedInspectorRecord, isNull);
      expect(dbService.getRunCount(), equals(0));
    });

    test('loadDemoWalkthroughData and clearDemoWalkthroughData aliases work', () {
      viewModel.loadDemoWalkthroughData();
      expect(viewModel.isDemoWalkthroughActive, isTrue);
      expect(viewModel.historicalRuns.length, equals(2));

      viewModel.clearDemoWalkthroughData();
      expect(viewModel.isDemoWalkthroughActive, isFalse);
      expect(viewModel.isDemoMode, isFalse);
      expect(viewModel.historicalRuns, isEmpty);
    });
  });

  group('GuidedTourOverlay & HomeScreen Demo Walkthrough E2E Tests', () {
    late Database inMemoryDb;
    late BenchmarkDatabaseService dbService;
    late BenchmarkRepository repository;
    late BenchmarkViewModel benchVm;
    late ServerViewModel serverVm;

    setUp(() {
      inMemoryDb = sqlite3.openInMemory();
      dbService = BenchmarkDatabaseService(db: inMemoryDb);
      repository = BenchmarkRepository(dbService: dbService);
      benchVm = BenchmarkViewModel(repository: repository);
      serverVm = ServerViewModel(repository: repository);
    });

    tearDown(() {
      benchVm.dispose();
      serverVm.dispose();
      repository.dispose();
    });

    Widget buildTestHost() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<BenchmarkViewModel>.value(value: benchVm),
          ChangeNotifierProvider<ServerViewModel>.value(value: serverVm),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: ThemeMode.dark,
          home: const HomeScreen(),
        ),
      );
    }

    testWidgets(
        'clicking Load Demo launches 5-step spotlight tour and Finish & Clear clears demo data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestHost());
      await tester.pumpAndSettle();

      // Starts in Idle state showing Load Demo
      expect(find.text('Load Demo'), findsOneWidget);
      expect(find.text('Exit Demo'), findsNothing);
      expect(find.text('0 runs stored'), findsOneWidget);
      expect(find.byType(GuidedTourOverlay), findsOneWidget);

      // Start Demo Walkthrough
      await tester.ensureVisible(find.text('Load Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load Demo'));
      await tester.pumpAndSettle();

      expect(benchVm.isDemoWalkthroughActive, isTrue);
      expect(benchVm.isDemoMode, isTrue);
      expect(find.text('Exit Demo'), findsOneWidget);
      expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsOneWidget);
      expect(
        find.text('Zone 2: Interface, Target & Protocol Controls'),
        findsOneWidget,
      );

      // Step 2: Zone 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 2 OF 5'), findsOneWidget);
      expect(find.text('Zone 3: Run Benchmark & Local Server'), findsOneWidget);

      // Step 3: Charts
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 3 OF 5'), findsOneWidget);
      expect(find.text('Real-Time Throughput & Jitter Charts'), findsOneWidget);

      // Step 4: History & Comparison (switches to Tab 1)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 4 OF 5'), findsOneWidget);
      expect(find.text('Benchmark Run History & Comparison'), findsOneWidget);
      expect(find.textContaining('COMPARISON MATRIX:'), findsOneWidget);
      expect(find.text('1G Full-Duplex'), findsWidgets);
      expect(find.text('UDP Jitter Check'), findsWidgets);

      // Back returns to Step 3 and Next advances to Step 4 again
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 3 OF 5'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 4 OF 5'), findsOneWidget);

      // Step 5: Inspector & Export (switches back to Tab 0)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 5 OF 5'), findsOneWidget);
      expect(find.text('Run Inspector & CSV/JSON Export'), findsOneWidget);
      expect(find.text('Finish & Clear'), findsOneWidget);
      expect(find.text('RUN ID: #demo-run-1'), findsOneWidget);

      // Finish & Clear exits tour and clears demo data
      await tester.tap(find.text('Finish & Clear'));
      await tester.pumpAndSettle();

      expect(benchVm.isDemoWalkthroughActive, isFalse);
      expect(benchVm.isDemoMode, isFalse);
      expect(find.textContaining('DEMO WALKTHROUGH'), findsNothing);
      expect(find.text('Load Demo'), findsOneWidget);
      expect(find.text('0 runs stored'), findsOneWidget);
      expect(dbService.getRunCount(), equals(0));
    });

    testWidgets('tapping End Demo or pressing Escape exits cleanly and clears demo data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestHost());
      await tester.pumpAndSettle();

      // Start walkthrough and exit via End Demo
      await tester.ensureVisible(find.text('Load Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load Demo'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsOneWidget);

      await tester.tap(find.text('End Demo'));
      await tester.pumpAndSettle();

      expect(benchVm.isDemoWalkthroughActive, isFalse);
      expect(benchVm.isDemoMode, isFalse);
      expect(find.text('Load Demo'), findsOneWidget);
      expect(find.text('0 runs stored'), findsOneWidget);

      // Start walkthrough again and exit via Escape key
      await tester.ensureVisible(find.text('Load Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load Demo'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO WALKTHROUGH • STEP 1 OF 5'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(benchVm.isDemoWalkthroughActive, isFalse);
      expect(benchVm.isDemoMode, isFalse);
      expect(find.text('Load Demo'), findsOneWidget);
      expect(find.text('0 runs stored'), findsOneWidget);
    });

    testWidgets('tapping Exit Demo in Top Control Bar exits demo mode cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestHost());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Load Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load Demo'));
      await tester.pumpAndSettle();

      expect(benchVm.isDemoMode, isTrue);
      expect(benchVm.isDemoWalkthroughActive, isTrue);
      expect(find.text('Exit Demo'), findsOneWidget);

      // Tapping Exit Demo in Top Control Bar should pass through the overlay
      // and clear both the walkthrough and all demo data.
      await tester.ensureVisible(find.text('Exit Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit Demo'));
      await tester.pumpAndSettle();

      expect(benchVm.isDemoMode, isFalse);
      expect(benchVm.isDemoWalkthroughActive, isFalse);
      expect(find.textContaining('DEMO WALKTHROUGH'), findsNothing);
      expect(find.text('Load Demo'), findsOneWidget);
      expect(find.text('0 runs stored'), findsOneWidget);
    });
  });

  group('Light & Dark Mode Tokens & SharedDeviceDatabase Sync', () {
    test('AppTheme dynamic getters return exact dark and light hex tokens', () {
      AppTheme.isDark = true;
      expect(AppTheme.scaffoldBg, equals(const Color(0xFF141414)));
      expect(AppTheme.surface, equals(const Color(0xFF1E1E1E)));
      expect(AppTheme.surfaceHigh, equals(const Color(0xFF252526)));
      expect(AppTheme.surfaceElevated, equals(const Color(0xFF2D2D2D)));
      expect(AppTheme.surfaceHighest, equals(const Color(0xFF323232)));
      expect(AppTheme.inputFill, equals(const Color(0xFF252526)));
      expect(AppTheme.border, equals(const Color(0xFF2C2C2C)));
      expect(AppTheme.textPrimary, equals(const Color(0xFFE0E0E0)));
      expect(AppTheme.textSecondary, equals(const Color(0xFF9E9E9E)));
      expect(AppTheme.textMuted, equals(const Color(0xFF6E6E6E)));
      expect(AppTheme.accent, equals(const Color(0xFF007ACC)));
      expect(AppTheme.primary, equals(const Color(0xFF007ACC)));
      expect(AppTheme.primaryLight, equals(const Color(0xFF38BDF8)));
      expect(AppTheme.success, equals(const Color(0xFF10B981)));
      expect(AppTheme.warning, equals(const Color(0xFFF59E0B)));
      expect(AppTheme.error, equals(const Color(0xFFEF4444)));
      expect(AppTheme.info, equals(const Color(0xFF3B82F6)));
      expect(AppTheme.commandBg, equals(const Color(0xFF0F141C)));
      expect(AppTheme.codeText, equals(const Color(0xFFE6EDF3)));

      AppTheme.isDark = false;
      expect(AppTheme.scaffoldBg, equals(const Color(0xFFF3F4F6)));
      expect(AppTheme.surface, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.surfaceHigh, equals(const Color(0xFFF9FAFB)));
      expect(AppTheme.surfaceElevated, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.surfaceHighest, equals(const Color(0xFFE5E7EB)));
      expect(AppTheme.inputFill, equals(const Color(0xFFF9FAFB)));
      expect(AppTheme.border, equals(const Color(0xFFE5E7EB)));
      expect(AppTheme.textPrimary, equals(const Color(0xFF111827)));
      expect(AppTheme.textSecondary, equals(const Color(0xFF4B5563)));
      expect(AppTheme.textMuted, equals(const Color(0xFF6B7280)));
      expect(AppTheme.accent, equals(const Color(0xFF0284C7)));
      expect(AppTheme.primary, equals(const Color(0xFF0284C7)));
      expect(AppTheme.primaryLight, equals(const Color(0xFF0284C7)));
      expect(AppTheme.success, equals(const Color(0xFF059669)));
      expect(AppTheme.warning, equals(const Color(0xFFD97706)));
      expect(AppTheme.error, equals(const Color(0xFFDC2626)));
      expect(AppTheme.info, equals(const Color(0xFF2563EB)));
      expect(AppTheme.commandBg, equals(const Color(0xFFF1F5F9)));
      expect(AppTheme.codeText, equals(const Color(0xFF0F172A)));
    });

    testWidgets(
        'NetBenchApp synchronizes theme brightness with SharedDeviceDatabase updates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tempDir = Directory.systemTemp.createTempSync('net_bench_theme_');
      final tempDbPath = p.join(tempDir.path, 'shared_devices.db');
      final sharedDb = SharedDeviceDatabase(customPath: tempDbPath);
      await sharedDb.setThemeMode('dark');

      final inMemoryDb = sqlite3.openInMemory();
      final dbService = BenchmarkDatabaseService(db: inMemoryDb);
      final repository = BenchmarkRepository(dbService: dbService);
      final benchVm = BenchmarkViewModel(repository: repository);
      final serverVm = ServerViewModel(repository: repository);

      addTearDown(() {
        benchVm.dispose();
        serverVm.dispose();
        repository.dispose();
        sharedDb.dispose();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BenchmarkViewModel>.value(value: benchVm),
            ChangeNotifierProvider<ServerViewModel>.value(value: serverVm),
          ],
          child: NetBenchApp(sharedDatabase: sharedDb),
        ),
      );
      await tester.pumpAndSettle();

      expect(AppTheme.isDark, isTrue);
      expect(
        Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        equals(Brightness.dark),
      );

      // Switch to light mode via SharedDeviceDatabase
      await sharedDb.setThemeMode('light');
      await tester.pumpAndSettle();

      expect(AppTheme.isDark, isFalse);
      expect(
        Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        equals(Brightness.light),
      );

      // Switch back to dark mode via SharedDeviceDatabase
      await sharedDb.setThemeMode('dark');
      await tester.pumpAndSettle();

      expect(AppTheme.isDark, isTrue);
      expect(
        Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        equals(Brightness.dark),
      );
    });
  });
}
