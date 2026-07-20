import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/camera_image_utils.dart';
import 'add_item_screen.dart';
import 'bulk_restock_confirm_screen.dart';

enum BulkScanMode { barcode, qr }

class BulkRestockScannerScreen extends StatefulWidget {
  final BulkScanMode mode;

  const BulkRestockScannerScreen({
    super.key,
    this.mode = BulkScanMode.barcode,
  });

  @override
  State<BulkRestockScannerScreen> createState() =>
      _BulkRestockScannerScreenState();
}

class _BulkRestockScannerScreenState extends State<BulkRestockScannerScreen> {
  static const _scanInterval = Duration(milliseconds: 300);

  CameraController? _cameraController;
  BarcodeScanner? _barcodeScanner;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  DateTime? _lastScanTime;
  int _warmupFrames = 3;

  // Keyed by item.id so duplicate scans increment qty
  final Map<int, RestockEntry> _entries = {};

  bool get _isQrMode => widget.mode == BulkScanMode.qr;

  List<BarcodeFormat> get _scanFormats => _isQrMode
      ? [BarcodeFormat.qrCode]
      : [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.upca,
        ];

  @override
  void initState() {
    super.initState();
    _barcodeScanner = BarcodeScanner(formats: _scanFormats);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage =
            'Camera permission denied. Please enable it in settings.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);
      await _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialize camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_warmupFrames > 0) {
      _warmupFrames--;
      return;
    }
    if (_isProcessing) return;
    final now = DateTime.now();
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!) < _scanInterval) return;
    _lastScanTime = now;
    _isProcessing = true;
    _scanFrame(image);
  }

  Future<void> _scanFrame(CameraImage image) async {
    try {
      final inputImage = cameraImageToInputImage(
        image: image,
        camera: _cameraController!.description,
        deviceOrientation: _cameraController!.value.deviceOrientation,
      );
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final barcodes = await _barcodeScanner!.processImage(inputImage);
      if (!mounted) {
        _isProcessing = false;
        return;
      }

      if (barcodes.isEmpty) {
        _isProcessing = false;
        return;
      }

      final barcodeValue = barcodes.first.rawValue;
      if (barcodeValue == null || barcodeValue.isEmpty) {
        _isProcessing = false;
        return;
      }

      if (_cameraController?.value.isStreamingImages ?? false) {
        await _cameraController!.stopImageStream();
      }
      await _handleScan(barcodeValue);
    } catch (_) {
      _isProcessing = false;
    }
  }

  Future<void> _handleScan(String barcodeValue) async {
    if (!mounted) return;

    final item = await DatabaseHelper().getItemByBarcode(barcodeValue);
    if (!mounted) return;

    if (item == null) {
      // Unknown item — let user fill in details, then add to list
      final newItem = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddItemScreen(barcode: barcodeValue),
        ),
      );
      if (!mounted) return;
      if (newItem != null) {
        // Initial qty set in AddItemScreen IS the restock — don't double-count
        _showFeedback('✓ ${newItem.name} added to inventory');
      }
    } else {
      if (_entries.containsKey(item.id!)) {
        _showFeedback('${item.name} already in list');
      } else {
        setState(() => _entries[item.id!] = RestockEntry(item: item, qty: 1));
        _showFeedback('✓ ${item.name}');
      }
    }

    _resumeScanning();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1400),
        backgroundColor: AppColors.ink,
      ),
    );
  }

  void _resumeScanning() {
    _isProcessing = false;
    _lastScanTime = null;
    _warmupFrames = 3;
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.isStreamingImages) {
      _cameraController!
          .startImageStream(_processCameraImage)
          .catchError((_) => _isProcessing = false);
    }
  }

  Future<void> _openReview() async {
    if (_entries.isEmpty) return;

    if (_cameraController?.value.isStreamingImages ?? false) {
      await _cameraController!.stopImageStream();
    }
    if (!mounted) return;

    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BulkRestockConfirmScreen(entries: _entries.values.toList()),
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      Navigator.pop(context);
    } else {
      _resumeScanning();
    }
  }

  @override
  void dispose() {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream().catchError((_) {});
      }
      _cameraController!.dispose();
    }
    _barcodeScanner?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final count = _entries.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: Stack(
        children: [
          _buildBody(),

          // Header overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Symbols.arrow_back,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isQrMode ? 'Bulk Restock — QR' : 'Bulk Restock — Barcode',
                      style: bricolage(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  if (count > 0)
                    GestureDetector(
                      onTap: _openReview,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Review $count',
                              style: instrument(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Symbols.arrow_forward,
                                size: 15, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.error, color: AppColors.red, size: 64),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: instrument(fontSize: 16, color: Colors.white)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        _buildScanOverlay(),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        SizedBox(
          width: 290,
          height: _isQrMode ? 260 : 200,
          child: Stack(
            children: [
              _Corner(top: true, left: true),
              _Corner(top: true, left: false),
              _Corner(top: false, left: true),
              _Corner(top: false, left: false),
              Center(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.greenFrame,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.greenFrame.withValues(alpha: 0.7),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _isQrMode
                ? 'Align QR code within the frame to scan'
                : 'Align barcode within the frame to scan',
            style: instrument(fontSize: 13.5, color: const Color(0xFFEFEDEA)),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

// ── Corner bracket ────────────────────────────────────────────────────────────

class _Corner extends StatelessWidget {
  final bool top;
  final bool left;

  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(
          painter: _CornerPainter(top: top, left: left),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;

  const _CornerPainter({required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.greenFrame
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final r = const Radius.circular(4);
    final path = Path();

    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, r.x);
      path.arcToPoint(Offset(r.x, 0), radius: r);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width - r.x, 0);
      path.arcToPoint(Offset(size.width, r.y), radius: r);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - r.y);
      path.arcToPoint(Offset(r.x, size.height), radius: r);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - r.y);
      path.arcToPoint(Offset(size.width - r.x, size.height), radius: r);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
