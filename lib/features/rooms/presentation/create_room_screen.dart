import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/spotify_oauth_repository.dart';
import '../data/rooms_repository.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.length < 2) return _message('Escribe un nombre de al menos 2 caracteres');
    setState(() => _loading = true);
    try {
      final api = ApiClient(ref.read(appConfigProvider), const FlutterSecureStorage());
      await SpotifyOauthRepository(api).connect();
      final room = await RoomsRepository(api, ref.read(appConfigProvider), ref.read(authRepositoryProvider)).create(name);
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
      appBar: AppBar(title: const Text('Crear sala')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('El anfitrión deberá conectar una cuenta Spotify Premium.'),
          const SizedBox(height: 24),
          TextField(controller: _nameController, maxLength: 32, textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Tu nombre', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(onPressed: _loading ? null : _create, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text('Conectar Spotify y crear'))
        ])
      )
    );
  }
}
