import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database_helper.dart';
import '../models/item.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/camera_image_utils.dart';
import '../widgets/item_action_sheet.dart';
import 'add_item_screen.dart';
import 'cart_screen.dart';

enum ScanMode { barcode, qr }

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

  bool get _isQrMode => widget.mode == ScanMode.qr;

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

      setState(() {
        _isCameraInitialized = true;
      });

      await _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  void _processCameraImage(CameraImage image) {
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
      assert(() {
        debugPrint('Scan frame error: $e');
        return true;
      }());
    }
  }

  Future<void> _handleBarcodeDetected(String barcodeValue) async {
    if (!mounted) return;

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
      if (mounted) {
        Navigator.pop(context, result);
      }
    } else {
      await _showItemActions(item);
    }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.check_circle, color: AppColors.sell, size: 48),
              const SizedBox(height: 12),
              Text(
                'Done!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'What would you like to do next?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeScanning();
                },
                icon: Icon(_isQrMode ? Icons.qr_code_2 : Icons.barcode_reader),
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
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text('View Cart ($cartCount items)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.home_outlined),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isQrMode ? 'Scan QR Code' : 'Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: CartService().cartCount,
            builder: (_, count, __) {
              if (count == 0) return const SizedBox.shrink();
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () async {
                      if (_cameraController?.value.isStreamingImages ?? false) {
                        await _cameraController!.stopImageStream();
                      }
                      if (!mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.sell,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          width: _isQrMode ? 260 : null,
          height: _isQrMode ? 260 : 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(_isQrMode ? 16 : 12),
          ),
          child: Stack(
            children: [
              _buildCorner(top: true, left: true),
              _buildCorner(top: true, left: false),
              _buildCorner(top: false, left: true),
              _buildCorner(top: false, left: false),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _isQrMode
                ? 'Align QR code within the frame to scan'
                : 'Align barcode within the frame to scan',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildCorner({required bool top, required bool left}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            bottom: top
                ? BorderSide.none
                : const BorderSide(color: Colors.green, width: 4),
            left: left
                ? const BorderSide(color: Colors.green, width: 4)
                : BorderSide.none,
            right: left
                ? BorderSide.none
                : const BorderSide(color: Colors.green, width: 4),
          ),
        ),
      ),
    );
  }
}
