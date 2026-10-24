import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/product_thumb.dart';
import '../../../shared/widgets/snackbars.dart';
import '../domain/product.dart';
import 'barcode_capture_page.dart';
import 'my_products_controller.dart';

/// Formulario para crear (o editar) un producto propio: nombre, marca, tamaño,
/// código de barras opcional y una foto sacada por la persona.
/// Al guardar devuelve el [Product] con `Navigator.pop`.
class CreateProductPage extends ConsumerStatefulWidget {
  const CreateProductPage({
    super.key,
    this.initialName,
    this.initialBarcode,
    this.existing,
  });

  final String? initialName;
  final String? initialBarcode;

  /// Producto propio que se está editando.
  final Product? existing;

  @override
  ConsumerState<CreateProductPage> createState() => _CreateProductPageState();
}

class _CreateProductPageState extends ConsumerState<CreateProductPage> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _size;
  late final TextEditingController _barcode;
  String? _imagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? widget.initialName ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _size = TextEditingController(text: p?.quantityLabel ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _imagePath = p?.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _size.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _photo(Future<String?> Function() pick) async {
    try {
      final path = await pick();
      if (path != null && mounted) setState(() => _imagePath = path);
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeCapturePage()),
    );
    if (code != null && mounted) {
      setState(() => _barcode.text = code.replaceAll(RegExp(r'\D'), ''));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final product = await ref.read(myProductsProvider.notifier).save(
            id: widget.existing?.libraryId,
            name: _name.text,
            brand: _brand.text,
            quantityLabel: _size.text,
            barcode: _barcode.text,
            imagePath: _imagePath,
          );
      if (mounted) Navigator.of(context).pop(product);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final picker = ref.read(productPhotoPickerProvider);
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar producto' : 'Crear producto')),
      // El botón queda siempre a la vista (también con el teclado abierto).
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(editing ? 'Guardar cambios' : 'Guardar producto'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: ProductThumb(
                    imageUrl: _imagePath,
                    size: 180,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _photo(picker.takePhoto),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Sacar foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _photo(picker.pickFromGallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                    if (_imagePath != null)
                      TextButton(
                        onPressed: () => setState(() => _imagePath = null),
                        child: const Text('Quitar foto'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              hintText: 'Ej. Azúcar impalpable',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brand,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Marca',
              hintText: 'Ej. Dos Anclas',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _size,
            decoration: const InputDecoration(
              labelText: 'Tamaño',
              hintText: 'Ej. 300 g, 1 l, 6 x 330 ml',
              helperText: 'Con el tamaño, el escáner puede avisarte si el paquete es '
                  'de otro gramaje.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Código de barras (opcional)',
              helperText: 'Con el código, el escáner reconoce el producto en la góndola.',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear código',
                onPressed: _scan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
