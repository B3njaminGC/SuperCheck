import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exception.dart';

/// Saca o elige una foto para un producto propio y devuelve la ruta de una copia
/// guardada en el teléfono (o `null` si la persona cancela).
abstract class ProductPhotoPicker {
  Future<String?> takePhoto();
  Future<String?> pickFromGallery();
}

class DevicePhotoPicker implements ProductPhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<String?> takePhoto() => _pick(ImageSource.camera);

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    try {
      // Se achica la foto: alcanza para reconocer el envase y ocupa poco.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (picked == null) return null;

      // La foto del selector vive en una carpeta temporal: se copia a una propia.
      final base = await getApplicationDocumentsDirectory();
      final folder = Directory('${base.path}/product_photos');
      await folder.create(recursive: true);
      final target = File('${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg');
      await File(picked.path).copy(target.path);
      return target.path;
    } on PlatformException catch (e) {
      throw AppException(
        source == ImageSource.camera
            ? 'No pude abrir la cámara. Revisá que SuperCheck tenga permiso.'
            : 'No pude abrir la galería.',
        cause: e,
      );
    } on FileSystemException catch (e) {
      throw AppException('No pude guardar la foto en el teléfono.', cause: e);
    }
  }
}
