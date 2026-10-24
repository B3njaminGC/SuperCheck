import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pantalla mínima de cámara: lee un código de barras y lo devuelve (`Navigator.pop`).
class BarcodeCapturePage extends StatefulWidget {
  const BarcodeCapturePage({super.key});

  @override
  State<BarcodeCapturePage> createState() => _BarcodeCapturePageState();
}

class _BarcodeCapturePageState extends State<BarcodeCapturePage> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null || code.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código')),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Sin controlador propio: el widget maneja solo el ciclo de vida de la cámara.
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No se pudo iniciar la cámara.\n${error.errorCode.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.8),
            child: Text(
              'Apuntá al código de barras',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
