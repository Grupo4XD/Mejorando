import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';
import '../data/rooms_repository.dart';
import '../domain/room.dart';
import 'room_controller.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.code});
  final String code;
  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  late final RoomController _controller;
  String? _userId;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appConfigProvider);
    final api = ApiClient(config, const FlutterSecureStorage());
    _controller = RoomController(RoomsRepository(api, config, ref.read(authRepositoryProvider)), widget.code)..initialize();
    ref.read(authRepositoryProvider).userId().then((id) { if (mounted) setState(() => _userId = id); });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    await _controller.leave();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        if (_controller.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (_controller.room == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_controller.error ?? 'No se pudo abrir la sala')));
        final room = _controller.room!;
        final isHost = room.hostId == _userId;
        return Scaffold(
          appBar: AppBar(title: Text('Sala ${room.code}'), actions: [IconButton(onPressed: _leave, icon: const Icon(Icons.logout))]),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              _NowPlaying(track: room.currentTrack),
              const SizedBox(height: 16),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${room.members.length} personas en la sala', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: room.members.map((member) => Chip(label: Text(member.role == 'HOST' ? '${member.name} · anfitrión' : member.name))).toList())
              ]))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: _controller.actionLoading ? null : _controller.vote, icon: const Icon(Icons.thumb_down_alt_outlined), label: Text('Saltar (${room.voteCount}/${room.skipThreshold})'))),
                if (isHost) ...[const SizedBox(width: 10), IconButton.filledTonal(onPressed: _controller.actionLoading ? null : _controller.refresh, icon: const Icon(Icons.sync))]
              ]),
              if (isHost) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _showThreshold(room.skipThreshold), child: const Text('Cambiar votos necesarios'))),
              const SizedBox(height: 14),
              TextField(onChanged: _controller.search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar una canción', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              ..._controller.results.map((track) => _SearchTrack(track: track, onQueue: () => _controller.queue(track.id))),
              if (_controller.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_controller.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
            ])
          )
        );
      }
    );
  }

  Future<void> _showThreshold(int current) async {
    final controller = TextEditingController(text: current.toString());
    final value = await showDialog<int>(context: context, builder: (context) => AlertDialog(
      title: const Text('Votos para saltar'),
      content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), child: const Text('Guardar'))]
    ));
    controller.dispose();
    if (value != null) await _controller.setThreshold(value);
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.track});
  final Track? track;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 72, height: 72, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: track?.imageUrl != null ? Image.network(track!.imageUrl!, fit: BoxFit.cover) : const Icon(Icons.music_note, size: 36)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(track?.name ?? 'No hay reproducción activa', style: Theme.of(context).textTheme.titleMedium), if (track != null) Text(track!.artist, style: Theme.of(context).textTheme.bodyMedium)]))
        ])
      )
    );
  }
}

class _SearchTrack extends StatelessWidget {
  const _SearchTrack({required this.track, required this.onQueue});
  final Track track;
  final VoidCallback onQueue;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(width: 52, height: 52, child: track.imageUrl == null ? const Icon(Icons.music_note) : Image.network(track.imageUrl!, fit: BoxFit.cover)),
      title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(onPressed: onQueue, icon: const Icon(Icons.playlist_add))
    );
  }
}
