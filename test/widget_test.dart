import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/main.dart';
import 'package:kamaae/screens/barcode_scanner_screen.dart';

import 'helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('home shows today metrics and cash flow action', (tester) async {
    // runAsync allows sqflite_ffi's real isolate timers to complete.
    await tester.runAsync(() async {
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.text('Kamaae'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Profit'), findsOneWidget);
    expect(find.text('Cash Flow'), findsOneWidget);

    // Unmount before DB teardown to stop any in-flight queries.
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('scanner screen shows barcode title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BarcodeScannerScreen(mode: ScanMode.barcode),
      ),
    );
    await tester.pump();

    expect(find.text('Scan Barcode'), findsOneWidget);
  });

  testWidgets('scanner screen shows qr title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BarcodeScannerScreen(mode: ScanMode.qr),
      ),
    );
    await tester.pump();

    expect(find.text('Scan QR Code'), findsOneWidget);
  });
}
