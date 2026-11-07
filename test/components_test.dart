import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:net_bench/data/repositories/benchmark_repository.dart';
import 'package:net_bench/data/services/database/benchmark_database_service.dart';
import 'package:net_bench/domain/models/benchmark_result.dart';
import 'package:net_bench/ui/theme/app_theme.dart';
import 'package:net_bench/ui/view_models/server_view_model.dart';
import 'package:net_bench/ui/views/widgets/common/empty_state_card.dart';
import 'package:net_bench/ui/views/widgets/history/comparison_matrix_card.dart';
import 'package:net_bench/ui/views/widgets/history/history_data_table.dart';
import 'package:net_bench/ui/views/widgets/server/server_monitor_card.dart';

void main() {
  group('EmptyStateCard Widget Tests', () {
    testWidgets('renders icon, title, subtitle, and fires action callbacks',
        (WidgetTester tester) async {
      bool primaryTapped = false;
      bool secondaryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: EmptyStateCard(
              icon: Icons.network_check,
              title: 'Ready for Benchmark',
              subtitle: 'Configure your target host and click start.',
              primaryActionLabel: 'Run Quick Test',
              onPrimaryAction: () => primaryTapped = true,
              secondaryActionLabel: 'View Docs',
              onSecondaryAction: () => secondaryTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.network_check), findsOneWidget);
      expect(find.text('Ready for Benchmark'), findsOneWidget);
      expect(find.text('Configure your target host and click start.'), findsOneWidget);
      expect(find.text('Run Quick Test'), findsOneWidget);
      expect(find.text('View Docs'), findsOneWidget);

      await tester.tap(find.text('Run Quick Test'));
      await tester.pump();
      expect(primaryTapped, isTrue);

      await tester.tap(find.text('View Docs'));
      await tester.pump();
      expect(secondaryTapped, isTrue);
    });
  });

  group('ComparisonMatrixCard Widget Tests', () {
    testWidgets('renders shrink SizedBox when fewer than 2 runs provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComparisonMatrixCard(
              runs: const [],
              onClearComparison: () {},
            ),
          ),
        ),
      );

      expect(find.byType(ComparisonMatrixCard), findsOneWidget);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders delta throughput, retransmit count, and triggers clear callback',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool clearTapped = false;
      final run1 = BenchmarkResult(
        id: 'run-1',
        timestamp: DateTime(2026, 11, 1),
        profileName: 'Baseline Run',
        targetHost: '192.168.1.1',
        port: 5201,
        protocol: 'tcp',
        direction: 'upload',
        streams: 1,
        durationSeconds: 10,
        avgThroughputMbps: 500.0,
        peakThroughputMbps: 520.0,
        minThroughputMbps: 480.0,
        totalBytes: 5000000,
        retransmits: 2,
        jitterMs: 1.0,
      );

      final run2 = BenchmarkResult(
        id: 'run-2',
        timestamp: DateTime(2026, 11, 2),
        profileName: 'Tuned Run',
        targetHost: '192.168.1.1',
        port: 5201,
        protocol: 'tcp',
        direction: 'upload',
        streams: 4,
        durationSeconds: 10,
        avgThroughputMbps: 750.0,
        peakThroughputMbps: 800.0,
        minThroughputMbps: 700.0,
        totalBytes: 7500000,
        retransmits: 1,
        jitterMs: 0.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: ComparisonMatrixCard(
              runs: [run1, run2],
              onClearComparison: () => clearTapped = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('COMPARISON MATRIX: Baseline Run'), findsOneWidget);
      expect(find.textContaining('Tuned Run'), findsOneWidget);
      expect(find.textContaining('+250.0 Mbps'), findsOneWidget);
      expect(find.textContaining('+50.0%'), findsOneWidget);

      await tester.tap(find.text('CLEAR COMPARISON'));
      await tester.pump();
      expect(clearTapped, isTrue);
    });
  });

  group('HistoryDataTable Widget Tests', () {
    testWidgets('renders empty placeholder when runs list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: HistoryDataTable(
              runs: const [],
              selectedComparisonIds: const {},
              onToggleComparison: (_) {},
              selectedInspectorRecord: null,
              onSelectInspectorRecord: (_) {},
              onDeleteRun: (_) {},
              onExportCsv: (_) {},
              onExportJson: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('No historical benchmark runs found'), findsOneWidget);
    });

    testWidgets('renders rows and triggers callbacks on row selection, comparison toggle, and export',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final run = BenchmarkResult(
        id: 'run-alpha',
        timestamp: DateTime(2026, 11, 6, 12, 0, 0),
        profileName: '1G Full-Duplex',
        targetHost: '192.168.1.10',
        port: 5201,
        protocol: 'tcp',
        direction: 'upload',
        streams: 2,
        durationSeconds: 10,
        avgThroughputMbps: 940.5,
        peakThroughputMbps: 955.0,
        minThroughputMbps: 920.0,
        totalBytes: 11000000,
        retransmits: 4,
      );

      BenchmarkResult? inspectedRecord;
      String? toggledComparisonId;
      BenchmarkResult? exportedCsvRun;
      String? deletedRunId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: HistoryDataTable(
                runs: [run],
                selectedComparisonIds: const {},
                onToggleComparison: (id) => toggledComparisonId = id,
                selectedInspectorRecord: null,
                onSelectInspectorRecord: (r) => inspectedRecord = r,
                onDeleteRun: (id) => deletedRunId = id,
                onExportCsv: (r) => exportedCsvRun = r,
                onExportJson: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify row data rendered
      expect(find.text('1G Full-Duplex'), findsOneWidget);
      expect(find.text('192.168.1.10:5201'), findsOneWidget);
      expect(find.text('940.5 Mbps'), findsOneWidget);

      // Tap row to inspect
      await tester.tap(find.text('1G Full-Duplex'));
      await tester.pump();
      expect(inspectedRecord?.id, equals('run-alpha'));

      // Tap comparison checkbox
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(toggledComparisonId, equals('run-alpha'));

      // Tap actions popup menu to trigger export
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Export CSV'), findsOneWidget);

      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      expect(exportedCsvRun?.id, equals('run-alpha'));

      // Tap actions popup menu to trigger delete
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Delete Run'), findsOneWidget);

      await tester.tap(find.text('Delete Run'));
      await tester.pumpAndSettle();
      expect(deletedRunId, equals('run-alpha'));
    });
  });

  group('ServerMonitorCard Widget Tests', () {
    testWidgets('renders server controls and displays stopped status initially',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final db = sqlite3.openInMemory();
      final dbService = BenchmarkDatabaseService(db: db);
      final repository = BenchmarkRepository(dbService: dbService);
      final serverVm = ServerViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: ServerMonitorCard(
                serverVm: serverVm,
                binaryPath: 'iperf3',
              ),
            ),
          ),
        ),
      );

      expect(find.text('LOCAL IPERF3 SERVER DAEMON'), findsOneWidget);
      expect(find.text('STOPPED'), findsWidgets);
      expect(find.text('START SERVER'), findsOneWidget);
      expect(find.text('PORT'), findsOneWidget);

      repository.dispose();
      serverVm.dispose();
    });
  });
}
