import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import 'apk_downloader.dart';
import 'update_checker.dart';

/// Descarga la versión nueva dentro de la app (con barra de progreso), avisa cuando
/// terminó y deja abrir el instalador. Si algo falla, ofrece abrir la página en el navegador.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(info: info),
  );
}

enum _Phase { downloading, ready, error }

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.info});

  final UpdateInfo info;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  final _cancel = DownloadCancel();
  _Phase _phase = _Phase.downloading;
  int _received = 0;
  int _total = 0;
  File? _file;
  String? _message;
  bool _offerBrowser = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    final downloader = ref.read(apkDownloaderProvider);
    setState(() {
      _phase = _Phase.downloading;
      _received = 0;
      _total = 0;
      _message = null;
    });
    try {
      final file = await downloader.download(
        widget.info,
        cancel: _cancel,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _file = file;
        _phase = _Phase.ready;
      });
    } on DownloadCancelled {
      return;
    } on AppException catch (e) {
      _fail(e.message);
    } on Object {
      _fail('No se pudo descargar la actualización.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _message = message;
    });
  }

  Future<void> _install() async {
    final file = _file;
    if (file == null) return;
    final installer = ref.read(apkInstallerProvider);
    setState(() {
      _installing = true;
      _message = null;
    });
    final outcome = await installer.install(file.path);
    if (!mounted) return;
    setState(() {
      _installing = false;
      _offerBrowser = outcome == InstallOutcome.failed;
      _message = switch (outcome) {
        InstallOutcome.launched => null,
        InstallOutcome.needsPermission =>
          'Android necesita tu permiso para instalar. Activá "Permitir de esta fuente" '
              'para SuperCheck y volvé a tocar Instalar.',
        InstallOutcome.failed => 'No se pudo abrir el instalador.',
      };
    });
  }

  Future<void> _openBrowser() async {
    final page = widget.info.pageUrl ?? Uri.parse(AppConstants.releasesPage);
    await ref.read(urlOpenerProvider)(page);
  }

  static String _mb(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');

  String get _progressLabel {
    if (_total <= 0) return '${_mb(_received)} MB';
    final percent = (_received * 100 ~/ _total).clamp(0, 100);
    return '${_mb(_received)} de ${_mb(_total)} MB · $percent %';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    final Widget content;
    final List<Widget> actions;

    switch (_phase) {
      case _Phase.downloading:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Descargando la versión nueva…'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _total > 0 ? _received / _total : null),
            const SizedBox(height: 8),
            Text(_progressLabel, style: theme.textTheme.bodySmall),
          ],
        );
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ];
      case _Phase.ready:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Descarga completa',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Tocá Instalar para terminar de actualizar. Tus listas se conservan.'),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: TextStyle(color: error)),
            ],
          ],
        );
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (_offerBrowser)
            TextButton(
              onPressed: _openBrowser,
              child: const Text('Abrir en el navegador'),
            ),
          FilledButton(
            onPressed: _installing ? null : _install,
            child: const Text('Instalar'),
          ),
        ];
      case _Phase.error:
        content = Text(_message ?? 'No se pudo descargar la actualización.');
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: _openBrowser,
            child: const Text('Abrir en el navegador'),
          ),
          FilledButton(onPressed: _download, child: const Text('Reintentar')),
        ];
    }

    return AlertDialog(
      title: const Text('Actualizar SuperCheck'),
      content: content,
      actions: actions,
    );
  }
}
