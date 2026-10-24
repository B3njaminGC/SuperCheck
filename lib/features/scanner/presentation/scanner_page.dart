import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/scan_result.dart';
import 'scan_banner.dart';
import 'scan_controller.dart';

/// Cámara para verificar productos en la góndola contra la lista activa.
class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  Timer? _autoDismiss;

  // Solo se reanuda la cámara si la apagamos nosotros al ir a segundo plano. Si no, al
  // volver del cuadro de permiso se pedía un segundo arranque mientras el primero seguía
  // en curso y la cámara quedaba en error aunque el permiso estuviera concedido.
  bool _pausedByUs = false;

  // Evita contar dos veces el mismo código si la cámara lo relee de seguido.
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoDismiss?.cancel();
    _camera.dispose();
    super.dispose();
  }

  // Apaga la cámara al ir a segundo plano y la vuelve a prender al volver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_pausedByUs) {
          _pausedByUs = false;
          unawaited(_safely(_camera.start));
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_camera.value.isRunning) {
          _pausedByUs = true;
          unawaited(_safely(_camera.stop));
        }
    }
  }

  Future<void> _retry() async {
    _pausedByUs = false;
    try {
      await _camera.stop();
    } catch (_) {}
    await _safely(_camera.start);
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // start/stop pueden fallar si la cámara ya estaba en ese estado.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (code == null) return;

    final scan = ref.read(scanControllerProvider(widget.listId));
    if (scan.isBusy) return;

    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt) < const Duration(seconds: 1)) {
      return;
    }
    _lastCode = code;
    _lastAt = now;

    HapticFeedback.mediumImpact();
    ref.read(scanControllerProvider(widget.listId).notifier).onBarcode(code);
  }

  @override
  Widget build(BuildContext context) {
    // Los aciertos exactos se cierran solos para seguir escaneando sin tocar nada.
    ref.listen<ScanState>(scanControllerProvider(widget.listId), (previous, next) {
      _autoDismiss?.cancel();
      if (next.result is ScanExactMatch) {
        _autoDismiss = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            ref.read(scanControllerProvider(widget.listId).notifier).dismiss();
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Escanear producto'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _camera,
            builder: (context, value, _) {
              final unavailable = value.torchState == TorchState.unavailable;
              return IconButton(
                tooltip: 'Linterna',
                icon: Icon(
                  value.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                ),
                onPressed: unavailable ? null : () => _camera.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) =>
                _CameraError(error: error, onRetry: _retry),
          ),
          // El marco se oculta si la cámara falló: ahí se muestra el aviso con "Reintentar".
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _camera,
            builder: (context, value, _) => value.error == null
                ? const IgnorePointer(child: _ScanFrame())
                : const SizedBox.shrink(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(child: ScanBanner(listId: widget.listId)),
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 280,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Apuntá al código de barras',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              denied
                  ? 'Necesito permiso para usar la cámara. '
                      'Activalo en los ajustes del teléfono.'
                  : 'No se pudo iniciar la cámara.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            // Detalle técnico: ayuda a entender qué falló si el problema sigue.
            Text(
              [
                error.errorCode.name,
                if (error.errorDetails?.message != null) error.errorDetails!.message!,
              ].join(': '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
