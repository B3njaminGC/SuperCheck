import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';
import '../../auth/presentation/auth_providers.dart';
import 'history_page.dart';
import 'list_detail_page.dart';
import 'lists_page.dart';
import 'lists_providers.dart';

/// Pantalla principal: pestañas "Listas" (activas) e "Historial" (finalizadas).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _index = 0;

  void _open(String listId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ListDetailPage(listId: listId)),
    );
  }

  Future<void> _createList() async {
    final name = await showTextPrompt(
      context,
      title: 'Nueva lista',
      hint: 'Ej. Compras del mes',
      confirmLabel: 'Crear',
    );
    if (name == null || !mounted) return;

    try {
      final list = await ref.read(listActionsProvider).create(name);
      if (mounted) _open(list.id);
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _joinList() async {
    final code = await showTextPrompt(
      context,
      title: 'Unirme a una lista',
      hint: 'Código de invitación',
      confirmLabel: 'Unirme',
      maxLength: 8,
      capitalization: TextCapitalization.characters,
    );
    if (code == null || !mounted) return;

    try {
      final listId = await ref.read(listActionsProvider).join(code);
      if (mounted) _open(listId);
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Mis listas' : 'Historial'),
        actions: [
          if (_index == 0)
            IconButton(
              icon: const Icon(Icons.group_add_outlined),
              tooltip: 'Unirme con código',
              onPressed: _joinList,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'logout') ref.read(authRepositoryProvider).signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(enabled: false, child: Text(email)),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: _index == 0
          ? ListsPage(onOpen: _open)
          : HistoryPage(onOpen: _open),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _createList,
              icon: const Icon(Icons.add),
              label: const Text('Nueva lista'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Listas',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}
