import 'package:equatable/equatable.dart';

import '../../products/domain/net_quantity.dart';
import '../../products/domain/product.dart';
import '../../shopping_list/domain/shopping_item.dart';

enum SizeRelation {
  /// El paquete escaneado es más chico: hay que llevar varios.
  smaller,

  /// Mismo contenido pero otro código de barras (otra variedad/presentación).
  same,

  /// El paquete escaneado es más grande que lo buscado.
  larger,

  /// No hay datos para comparar (sin gramos/ml, o unidades distintas).
  unknown,
}

/// Resultado de comparar lo que se busca (paquete × cantidad) con lo escaneado.
class SizeAdvice extends Equatable {
  const SizeAdvice({
    required this.relation,
    this.wantedTotal,
    this.scannedSize,
    this.unitsNeeded,
    this.exactFit = false,
  });

  final SizeRelation relation;

  /// Contenido que falta comprar (gramos por paquete × unidades pendientes).
  final NetQuantity? wantedTotal;
  final NetQuantity? scannedSize;

  /// Unidades del paquete escaneado para llegar a lo buscado.
  final int? unitsNeeded;

  /// `true` si esas unidades dan justo lo buscado (con 2% de tolerancia).
  final bool exactFit;

  static const _tolerance = 0.02;

  factory SizeAdvice.compute({
    required ShoppingItem item,
    required Product scanned,
  }) {
    // Lo que falta: si ya hay unidades en el carrito, no se vuelven a contar.
    final wanted = item.remainingNetQuantity;
    final size = scanned.netQuantity;

    if (wanted == null || size == null || !wanted.sameUnitAs(size)) {
      return SizeAdvice(
        relation: SizeRelation.unknown,
        wantedTotal: wanted,
        scannedSize: size,
      );
    }

    final ratio = wanted.value / size.value;

    if ((ratio - 1).abs() <= _tolerance) {
      return SizeAdvice(
        relation: SizeRelation.same,
        wantedTotal: wanted,
        scannedSize: size,
      );
    }

    if (ratio < 1) {
      return SizeAdvice(
        relation: SizeRelation.larger,
        wantedTotal: wanted,
        scannedSize: size,
        unitsNeeded: 1,
      );
    }

    final nearest = ratio.round();
    final fits = (ratio - nearest).abs() <= _tolerance * ratio;
    return SizeAdvice(
      relation: SizeRelation.smaller,
      wantedTotal: wanted,
      scannedSize: size,
      unitsNeeded: fits ? nearest : ratio.ceil(),
      exactFit: fits,
    );
  }

  /// Texto para el banner del escáner.
  String get message {
    final size = scannedSize?.toDisplayString();
    final wanted = wantedTotal?.toDisplayString();

    switch (relation) {
      case SizeRelation.unknown:
        return size == null
            ? 'No pude comparar el contenido: este producto no indica gramos ni mililitros.'
            : 'No pude comparar el contenido: las unidades de medida no coinciden.';
      case SizeRelation.same:
        return 'Tiene el mismo contenido ($size) pero otro código de barras: '
            'puede ser otra variedad o presentación.';
      case SizeRelation.larger:
        return 'Este paquete es de $size, más grande que los $wanted que buscabas.';
      case SizeRelation.smaller:
        final units = unitsNeeded!;
        final unitsText = units == 1 ? '1 unidad' : '$units unidades';
        final total = NetQuantity(scannedSize!.value * units, scannedSize!.unit)
            .toDisplayString();
        return exactFit
            ? 'Este paquete es de $size. Te sugerimos llevar $unitsText ($total en total).'
            : 'Este paquete es de $size y buscabas $wanted. '
                'Con $unitsText llevarías $total.';
    }
  }

  @override
  List<Object?> get props =>
      [relation, wantedTotal, scannedSize, unitsNeeded, exactFit];
}
