import 'package:equatable/equatable.dart';

enum ListStatus {
  active,
  completed;

  static ListStatus fromString(String? raw) {
    return raw == 'completed' ? ListStatus.completed : ListStatus.active;
  }
}

/// Una lista compartida. Mapea 1:1 con la tabla `lists`.
class ShoppingList extends Equatable {
  const ShoppingList({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.createdAt,
    this.status = ListStatus.active,
    this.completedAt,
    this.itemCount,
  });

  final String id;
  final String name;
  final String ownerId;

  /// Código de 8 caracteres que se comparte con la familia para unirse.
  final String inviteCode;
  final DateTime createdAt;

  final ListStatus status;

  /// Cuándo se finalizó (solo si [status] es `completed`).
  final DateTime? completedAt;

  /// Cantidad de productos; solo viene cargada en las consultas del historial.
  final int? itemCount;

  bool get isCompleted => status == ListStatus.completed;

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      inviteCode: json['invite_code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: ListStatus.fromString(json['status'] as String?),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      itemCount: _countFrom(json['list_items']),
    );
  }

  /// PostgREST devuelve `list_items: [{count: 12}]` al pedir `list_items(count)`.
  static int? _countFrom(Object? embedded) {
    if (embedded is List && embedded.isNotEmpty) {
      final first = embedded.first;
      if (first is Map && first['count'] is num) {
        return (first['count'] as num).toInt();
      }
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [id, name, ownerId, inviteCode, createdAt, status, completedAt, itemCount];
}
