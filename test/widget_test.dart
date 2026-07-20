import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/screens/barcode_scanner_screen.dart';

void main() {
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
