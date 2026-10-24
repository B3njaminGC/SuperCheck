import 'package:equatable/equatable.dart';

import '../../../core/utils/barcode_utils.dart';
import '../../products/domain/net_quantity.dart';

/// Un renglón de la lista: el producto elegido (marca + paquete + gramos) o un texto
/// libre (sin código de barras), y cuántas unidades hacen falta.
/// Mapea 1:1 con la tabla `list_items`.
///
/// Regla de estado: `isChecked == (pickedQty >= desiredQty)`. Todos los cambios pasan
/// por [withPicked], [withDesiredQty] o [toggled], que la mantienen.
class ShoppingItem extends Equatable {
  const ShoppingItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.createdAt,
    this.barcode,
    this.brand,
    this.quantityLabel,
    this.netQuantity,
    this.imageUrl,
    this.desiredQty = 1,
    this.pickedQty = 0,
    this.notes,
    this.isChecked = false,
    this.checkedBy,
    this.checkedAt,
    this.addedBy,
  });

  final String id;
  final String listId;
  final String name;
  final DateTime createdAt;

  final String? barcode;
  final String? brand;
  final String? quantityLabel;
  final NetQuantity? netQuantity;
  final String? imageUrl;

  /// Unidades que hacen falta y unidades que ya están en el carrito.
  final int desiredQty;
  final int pickedQty;
  final String? notes;

  final bool isChecked;
  final String? checkedBy;
  final DateTime? checkedAt;
  final String? addedBy;

  /// Contenido total buscado = gramos por paquete * unidades.
  NetQuantity? get totalNetQuantity {
    final net = netQuantity;
    return net == null ? null : NetQuantity(net.value * desiredQty, net.unit);
  }

  /// Unidades que faltan llevar.
  int get remainingQty => desiredQty > pickedQty ? desiredQty - pickedQty : 0;

  /// Contenido que falta llevar = gramos por paquete × unidades pendientes.
  /// `null` si no hay gramos/ml o si ya no falta nada.
  NetQuantity? get remainingNetQuantity {
    final net = netQuantity;
    if (net == null || remainingQty == 0) return null;
    return NetQuantity(net.value * remainingQty, net.unit);
  }

  /// "2 de 4" mientras falten unidades (solo si se piden varias y ya se llevó alguna).
  String? get progressLabel {
    if (desiredQty > 1 && pickedQty > 0 && !isChecked) {
      return '$pickedQty de $desiredQty';
    }
    return null;
  }

  /// "Criollitas · 300 g" (o solo lo que haya).
  String get subtitle {
    final size = netQuantity?.toDisplayString() ?? quantityLabel;
    return [brand, size]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');
  }

  bool matchesBarcode(String scanned) => BarcodeUtils.isSame(barcode, scanned);

  // --- Cambios de estado (siempre devuelven una copia) ----------------------

  /// Fija cuántas unidades están en el carrito (entre 0 y [desiredQty]).
  /// Al completarlas se tacha y se anota quién; si no, queda pendiente.
  ShoppingItem withPicked(int picked, {String? userId}) {
    final clamped = picked < 0 ? 0 : (picked > desiredQty ? desiredQty : picked);
    final done = clamped >= desiredQty;
    return _copy(
      pickedQty: clamped,
      isChecked: done,
      replaceCheckInfo: true,
      checkedBy: done ? userId : null,
      checkedAt: done ? DateTime.now() : null,
    );
  }

  /// Cambia la cantidad pedida (mínimo 1) y recalcula si ya está completo:
  /// subirla en un ítem completo lo vuelve pendiente; bajarla por debajo de lo
  /// llevado lo completa.
  ShoppingItem withDesiredQty(int qty, {String? userId}) {
    final wanted = qty < 1 ? 1 : qty;
    final picked = pickedQty > wanted ? wanted : pickedQty;
    final done = picked >= wanted;
    return _copy(
      desiredQty: wanted,
      pickedQty: picked,
      isChecked: done,
      replaceCheckInfo: true,
      checkedBy: done ? (checkedBy ?? userId) : null,
      checkedAt: done ? (checkedAt ?? DateTime.now()) : null,
    );
  }

  /// Toque manual: completo -> vuelve a 0; pendiente -> se completa de golpe.
  ShoppingItem toggled({String? userId}) {
    return isChecked ? withPicked(0) : withPicked(desiredQty, userId: userId);
  }

  ShoppingItem _copy({
    int? desiredQty,
    int? pickedQty,
    bool? isChecked,
    bool replaceCheckInfo = false,
    String? checkedBy,
    DateTime? checkedAt,
  }) {
    return ShoppingItem(
      id: id,
      listId: listId,
      name: name,
      createdAt: createdAt,
      barcode: barcode,
      brand: brand,
      quantityLabel: quantityLabel,
      netQuantity: netQuantity,
      imageUrl: imageUrl,
      desiredQty: desiredQty ?? this.desiredQty,
      pickedQty: pickedQty ?? this.pickedQty,
      notes: notes,
      isChecked: isChecked ?? this.isChecked,
      checkedBy: replaceCheckInfo ? checkedBy : this.checkedBy,
      checkedAt: replaceCheckInfo ? checkedAt : this.checkedAt,
      addedBy: addedBy,
    );
  }

  /// Mismo formato que la tabla `list_items` (lo usa el almacenamiento del modo local).
  Map<String, dynamic> toJson() => {
        'id': id,
        'list_id': listId,
        'name': name,
        'created_at': createdAt.toUtc().toIso8601String(),
        'barcode': barcode,
        'brand': brand,
        'quantity_label': quantityLabel,
        'net_quantity': netQuantity?.value,
        'net_unit': netQuantity?.unit.symbol,
        'image_url': imageUrl,
        'desired_qty': desiredQty,
        'picked_qty': pickedQty,
        'notes': notes,
        'is_checked': isChecked,
        'checked_by': checkedBy,
        'checked_at': checkedAt?.toUtc().toIso8601String(),
        'added_by': addedBy,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final netValue = json['net_quantity'];
    final netUnit = QuantityUnit.fromSymbol(json['net_unit'] as String?);

    return ShoppingItem(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      barcode: json['barcode'] as String?,
      brand: json['brand'] as String?,
      quantityLabel: json['quantity_label'] as String?,
      netQuantity: (netValue is num && netUnit != null)
          ? NetQuantity(netValue.toDouble(), netUnit)
          : null,
      imageUrl: json['image_url'] as String?,
      desiredQty: (json['desired_qty'] as num?)?.toInt() ?? 1,
      pickedQty: (json['picked_qty'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      isChecked: json['is_checked'] as bool? ?? false,
      checkedBy: json['checked_by'] as String?,
      checkedAt: json['checked_at'] == null
          ? null
          : DateTime.parse(json['checked_at'] as String),
      addedBy: json['added_by'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        listId,
        name,
        createdAt,
        barcode,
        brand,
        quantityLabel,
        netQuantity,
        imageUrl,
        desiredQty,
        pickedQty,
        notes,
        isChecked,
        checkedBy,
        checkedAt,
        addedBy,
      ];
}
