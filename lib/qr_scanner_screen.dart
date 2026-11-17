import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with WidgetsBindingObserver {
  final _controller = MobileScannerController(autoStart: false,
    formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.normal,
    returnImage: false);
  bool _starting = false;
  bool _showingResult = false;
  String? _startError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || _starting || _showingResult || _controller.value.isRunning) return;
    _starting = true;
    try {
      await _controller.start();
      if (mounted) setState(() => _startError = null);
    } catch (_) {
      if (mounted) setState(() => _startError = 'Не удалось открыть камеру. Проверьте разрешение в настройках приложения.');
    } finally { _starting = false; }
  }

  Future<void> _stop() async {
    try { await _controller.stop(); } catch (_) { /* The camera may already be closed. */ }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) { unawaited(_start()); }
    else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      unawaited(_stop());
    }
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (_showingResult || !mounted || !capture.barcodes.any((barcode) => barcode.format == BarcodeFormat.qrCode)) return;
    _showingResult = true;
    await _stop();
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      key: const Key('qr_unrecognized'), title: const Text('QR-код не распознан'),
      content: const Text('Попробуйте другой QR-код.'),
      actions: [TextButton(key: const Key('retry_qr'), onPressed: () => Navigator.pop(context),
        child: const Text('Попробовать ещё раз'))],
    ));
    _showingResult = false;
    if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) await _start();
  }

  Widget _error(String message) => Center(child: Padding(padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 40),
      const SizedBox(height: 16), Text(message, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16)),
      const SizedBox(height: 16), OutlinedButton(key: const Key('retry_camera'), onPressed: _start,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white), child: const Text('Повторить')),
    ])));

  Future<void> _toggleTorch() async {
    if (!_controller.value.isRunning) return;
    try { await _controller.toggleTorch(); } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Фонарик недоступен.')));
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white, systemNavigationBarIconBrightness: Brightness.dark),
    child: Scaffold(backgroundColor: const Color(0xFF202020),
    body: LayoutBuilder(builder: (context, constraints) {
      final insets = MediaQuery.paddingOf(context);
      final side = math.min(constraints.maxWidth * 0.66, constraints.maxHeight * 0.36);
      final window = Rect.fromCenter(center: Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.43),
        width: side, height: side);
      return Stack(children: [
        Positioned.fill(child: MobileScanner(key: const Key('qr_camera_preview'), controller: _controller,
          scanWindow: window, onDetect: _detect, errorBuilder: (context, error) => _error(
            error.errorCode == MobileScannerErrorCode.permissionDenied
              ? 'Разрешите доступ к камере в настройках приложения.' : 'Камера недоступна. Попробуйте ещё раз.'))),
        if (_startError != null) Positioned.fill(child: ColoredBox(color: const Color(0xFF202020), child: _error(_startError!))),
        Positioned.fill(child: ValueListenableBuilder<MobileScannerState>(valueListenable: _controller,
          builder: (_, state, child) => IgnorePointer(child: _startError == null && state.error == null
            ? CustomPaint(painter: _QrViewfinderPainter(window)) : const SizedBox.shrink()))),
        Positioned(top: insets.top + 10, left: 16, right: 16, height: 44, child: Stack(alignment: Alignment.center, children: [
          const Text('Kaspi QR', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: 34, height: 34,
            child: IconButton(key: const Key('qr_close'), tooltip: 'Закрыть', padding: EdgeInsets.zero,
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3EDF3), foregroundColor: const Color(0xFF333333),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 25)))),
        ])),
        Positioned(top: constraints.maxHeight * 0.165, left: 16, right: 16,
          child: const Text('QR-кодты сканерлеңіз', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white))),
        Positioned(top: window.bottom + 34, left: (constraints.maxWidth - 42) / 2, width: 42, height: 42,
          child: ValueListenableBuilder<MobileScannerState>(valueListenable: _controller,
            builder: (_, state, child) => IconButton(key: const Key('qr_torch'), tooltip: 'Фонарик',
              padding: EdgeInsets.zero, onPressed: state.isRunning && state.torchState != TorchState.unavailable ? _toggleTorch : null,
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFEFE9EF),
                disabledBackgroundColor: const Color(0xFFEFE9EF), foregroundColor: state.torchState == TorchState.on
                  ? const Color(0xFFFF603A) : const Color(0xFF282328),
                disabledForegroundColor: const Color(0xFF777177)),
              icon: const Icon(Icons.flashlight_on, size: 24)))),
        Positioned(left: 0, right: 0, bottom: 0, child: _QrOnlinePanel(
          height: math.max(144, constraints.maxHeight * 0.185) + insets.bottom, bottomInset: insets.bottom)),
      ]);
    })),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }
}

class _QrViewfinderPainter extends CustomPainter {
  const _QrViewfinderPainter(this.window);
  final Rect window;
  @override
  void paint(Canvas canvas, Size size) {
    final mask = Path()..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(8)));
    canvas.drawPath(mask, Paint()..color = const Color(0x88000000));
    final corners = Paint()..color = const Color(0xFFFF603A)..style = PaintingStyle.stroke
      ..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    const length = 32.0, radius = 8.0;
    final left = window.left, top = window.top, right = window.right, bottom = window.bottom;
    canvas.drawPath(Path()..moveTo(left, top + length)..lineTo(left, top + radius)
      ..quadraticBezierTo(left, top, left + radius, top)..lineTo(left + length, top), corners);
    canvas.drawPath(Path()..moveTo(right - length, top)..lineTo(right - radius, top)
      ..quadraticBezierTo(right, top, right, top + radius)..lineTo(right, top + length), corners);
    canvas.drawPath(Path()..moveTo(left, bottom - length)..lineTo(left, bottom - radius)
      ..quadraticBezierTo(left, bottom, left + radius, bottom)..lineTo(left + length, bottom), corners);
    canvas.drawPath(Path()..moveTo(right - length, bottom)..lineTo(right - radius, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - radius)..lineTo(right, bottom - length), corners);
  }
  @override
  bool shouldRepaint(_QrViewfinderPainter oldDelegate) => oldDelegate.window != window;
}

class _QrOnlinePanel extends StatelessWidget {
  const _QrOnlinePanel({required this.height, required this.bottomInset});
  final double height, bottomInset;
  @override
  Widget build(BuildContext context) => Container(key: const Key('qr_online_panel'),
    height: height, padding: EdgeInsets.fromLTRB(20, 10, 18, bottomInset + 12),
    decoration: const BoxDecoration(color: Color(0xFFFFFCFE),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 31, height: 3, decoration: BoxDecoration(
        color: const Color(0xFFD5D1D4), borderRadius: BorderRadius.circular(3)))),
      const SizedBox(height: 19),
      const Text('Онлайн рәсімдеу', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Color(0xFF262326))),
      const SizedBox(height: 19),
      InkWell(key: const Key('qr_installment'), onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Онлайн рәсімдеу қолжетімсіз.'))),
        child: Row(children: [
          Container(width: 30, height: 30, alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFFFC21A), borderRadius: BorderRadius.circular(3)),
            child: const Text('0·0·12', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF4D3820)))),
          const SizedBox(width: 15),
          const Expanded(child: Text('Бөліп төлеу 0-0-12', style: TextStyle(fontSize: 13, color: Color(0xFF727072)))),
          const Icon(Icons.chevron_right, size: 23, color: Color(0xFFB7B3B6)),
        ])),
    ]),
  );
}
