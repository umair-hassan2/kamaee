import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database_helper.dart';
import '../models/item.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/camera_image_utils.dart';
import '../widgets/item_action_sheet.dart';
import 'add_item_screen.dart';
import 'cart_screen.dart';
import 'sale_detail_screen.dart';

enum ScanMode { barcode, qr, bill }

class BarcodeScannerScreen extends StatefulWidget {
  final ScanMode mode;

  const BarcodeScannerScreen({super.key, this.mode = ScanMode.barcode});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  static const _scanInterval = Duration(milliseconds: 300);

  CameraController? _cameraController;
  BarcodeScanner? _barcodeScanner;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  DateTime? _lastScanTime;
  int _warmupFrames = 3;

  bool get _isQrMode => widget.mode == ScanMode.qr;
  bool get _isBillMode => widget.mode == ScanMode.bill;

  List<BarcodeFormat> get _scanFormats {
    if (_isQrMode) return [BarcodeFormat.qrCode];
    if (_isBillMode) return [BarcodeFormat.code128];
    return [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.upca,
    ];
  }

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
        now.difference(_lastScanTime!) < _scanInterval) {
      return;
    }
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
      if (!mounted) return;

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
      await _handleBarcodeDetected(barcodeValue);
    } catch (e) {
      _isProcessing = false;
    }
  }

  Future<void> _handleBarcodeDetected(String barcodeValue) async {
    if (!mounted) return;

    if (_isBillMode) {
      await _handleBillBarcode(barcodeValue);
      return;
    }

    final db = DatabaseHelper();
    final item = await db.getItemByBarcode(barcodeValue);

    if (!mounted) return;

    if (item == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddItemScreen(barcode: barcodeValue),
        ),
      );
      if (mounted) Navigator.pop(context, result);
    } else {
      await _showItemActions(item);
    }
  }

  Future<void> _handleBillBarcode(String value) async {
    if (!mounted) return;

    if (!value.startsWith('KAM:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid barcode — this doesn\'t look like a bill'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _resumeScanning();
      return;
    }

    final saleId = int.tryParse(value.substring(4));
    if (saleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid bill format — could not read bill ID'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _resumeScanning();
      return;
    }

    final db = DatabaseHelper();
    final sale = await db.getSaleById(saleId);

    if (!mounted) return;

    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sale #$saleId not found — bill may be from a different device'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _resumeScanning();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showItemActions(Item item) async {
    if (!mounted) return;

    await showItemActionSheet(
      context: context,
      item: item,
      showAddToCart: true,
      onDone: () {
        Navigator.pop(context);
        _showAfterActionPrompt();
      },
      onCancel: () {
        Navigator.pop(context);
        _resumeScanning();
      },
    );
  }

  Future<void> _showAfterActionPrompt() async {
    if (!mounted) return;

    final cartCount = CartService().cartCount.value;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.check,
                    color: AppColors.green, size: 30),
              ),
              const SizedBox(height: 12),
              Text('Done!',
                  textAlign: TextAlign.center,
                  style: bricolage(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('What would you like to do next?',
                  textAlign: TextAlign.center,
                  style: instrument(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeScanning();
                },
                icon: Icon(_isQrMode
                    ? Symbols.qr_code_2
                    : Symbols.barcode_scanner),
                label: const Text('Scan Next Item'),
              ),
              if (cartCount > 0) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Symbols.shopping_cart),
                  label: Text('View Cart ($cartCount items)'),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                icon: const Icon(Symbols.home),
                label: const Text('Finish'),
              ),
            ],
          ),
        ),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: Stack(
        children: [
          _buildBody(),

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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isBillMode
                          ? 'Scan Bill Barcode'
                          : _isQrMode
                              ? 'Scan QR Code'
                              : 'Scan Barcode',
                      style: bricolage(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: CartService().cartCount,
                    builder: (_, count, __) {
                      if (_isBillMode || count == 0) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          if (_cameraController?.value.isStreamingImages ??
                              false) {
                            await _cameraController!.stopImageStream();
                          }
                          if (!mounted) return;
                          await navigator.push(
                            MaterialPageRoute(
                                builder: (_) => const CartScreen()),
                          );
                          navigator.pop();
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Symbols.shopping_cart,
                                size: 24, color: Colors.white),
                            Positioned(
                              top: -6,
                              right: -8,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: mono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: instrument(fontSize: 16, color: Colors.white),
              ),
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
        child: CircularProgressIndicator(color: Colors.white),
      );
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
              const _Corner(top: true, left: true),
              const _Corner(top: true, left: false),
              const _Corner(top: false, left: true),
              const _Corner(top: false, left: false),
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
            _isBillMode
                ? 'Align bill barcode within the frame to scan'
                : _isQrMode
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

    const r = Radius.circular(4);
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
