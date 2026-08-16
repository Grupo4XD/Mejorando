import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../data/rooms_repository.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});
  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (name.length < 2 || code.length < 6) return _message('Completa tu nombre y el código de sala');
    setState(() => _loading = true);
    try {
      final config = ref.read(appConfigProvider);
      final api = ApiClient(config, const FlutterSecureStorage());
      final room = await RoomsRepository(api, config, ref.read(authRepositoryProvider)).join(code, name);
      if (mounted) context.go('/room/${room.code}');
    } catch (exception) {
      _message(exception.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme a una sala')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _nameController, maxLength: 32, decoration: const InputDecoration(labelText: 'Tu nombre', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _codeController, maxLength: 12, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Código de sala', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(onPressed: _loading ? null : _join, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text('Entrar'))
        ])
      )
    );
  }
}
