import 'package:equatable/equatable.dart';

/// Persona que participa de una lista. Viene de `list_members` + `profiles`.
class ListMember extends Equatable {
  const ListMember({
    required this.userId,
    required this.displayName,
    required this.isOwner,
    required this.joinedAt,
  });

  final String userId;
  final String displayName;
  final bool isOwner;
  final DateTime joinedAt;

  factory ListMember.fromJson(Map<String, dynamic> json) {
    // PostgREST devuelve la relación como objeto: `profiles: {display_name: ...}`.
    final profile = json['profiles'];
    final rawName = profile is Map ? profile['display_name'] as String? : null;
    final name = (rawName ?? '').trim();

    return ListMember(
      userId: json['user_id'] as String,
      displayName: name.isEmpty ? 'Sin nombre' : name,
      isOwner: json['role'] == 'owner',
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  @override
  List<Object?> get props => [userId, displayName, isOwner, joinedAt];
}
